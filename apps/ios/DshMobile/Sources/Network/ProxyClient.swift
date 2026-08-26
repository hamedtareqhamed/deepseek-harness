//
//  ProxyClient.swift
//  DshMobile
//
//  Handles HTTP REST requests and SSE event streaming to dsh-http-proxy.
//

import Foundation

public actor ProxyClient {
    private var baseURL: URL
    private var bearerToken: String
    private let session: URLSession

    public init(baseURL: URL, bearerToken: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
        self.session = session
    }

    public func updateConfig(baseURL: URL, bearerToken: String) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    // MARK: - Health Check

    public func checkHealth() async throws -> Bool {
        let req = makeRequest(path: "health")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["ok"] as? Bool ?? false
    }

    // MARK: - Sessions

    public func fetchSessions() async throws -> [SessionSummary] {
        let req = makeRequest(path: "api/sessions")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(SessionsListResponse.self, from: data)
        return decoded.sessions.sorted { $0.createdAt > $1.createdAt }
    }

    public func createSession(customId: String? = nil) async throws -> String {
        var bodyData: Data? = nil
        if let customId = customId {
            bodyData = try JSONEncoder().encode(["sessionId": customId])
        }
        let req = makeRequest(path: "api/sessions", method: "POST", body: bodyData)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(CreateSessionResponse.self, from: data)
        return decoded.sessionId
    }

    // MARK: - Prompts

    public func sendPrompt(sessionId: String, text: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        let req = makeRequest(path: "api/sessions/\(sessionId)/prompt", method: "POST", body: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "ProxyClient", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Failed to send prompt"])
        }
        let decoded = try JSONDecoder().decode(PromptResponse.self, from: data)
        return decoded.messageId
    }

    // MARK: - Streaming

    public func streamEvents(sessionId: String, fromSeq: Int = -1) async throws -> AsyncStream<SSEEvent> {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("api/sessions/\(sessionId)/stream"), resolvingAgainstBaseURL: false)!
        if fromSeq >= 0 {
            urlComponents.queryItems = [URLQueryItem(name: "from", value: "\(fromSeq)")]
        }

        var req = URLRequest(url: urlComponents.url!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 3600 // Long-lived stream connection

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return SSEParser.parse(lines: bytes.lines)
    }

    // MARK: - Approval

    public func submitApproval(sessionId: String, decision: String) async throws -> Bool {
        let body = try JSONSerialization.data(withJSONObject: ["decision": decision])
        let req = makeRequest(path: "api/sessions/\(sessionId)/approve", method: "POST", body: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return false
        }
        let decoded = try JSONDecoder().decode(ApproveResponse.self, from: data)
        return decoded.ok
    }
}

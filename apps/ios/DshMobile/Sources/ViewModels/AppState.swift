//
//  AppState.swift
//  DshMobile
//
//  Core application state: manages active session, live message list, streaming tokens,
//  tool execution cards, and approval alerts.
//

import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "dsh_server_url"); updateClient() }
    }
    @Published public var bearerToken: String {
        didSet { UserDefaults.standard.set(bearerToken, forKey: "dsh_bearer_token"); updateClient() }
    }

    @Published public var isConnected: Bool = false
    @Published public var sessions: [SessionSummary] = []
    @Published public var activeSessionId: String?

    @Published public var messages: [ChatMessage] = []
    @Published public var isStreaming: Bool = false
    @Published public var lastReceivedSeq: Int = -1

    @Published public var activeApproval: ApprovalRequest?
    @Published public var errorMessage: String?

    private var client: ProxyClient
    private var streamTask: Task<Void, Never>?

    public init() {
        let savedURL = UserDefaults.standard.string(forKey: "dsh_server_url") ?? "http://100.x.x.x:3090"
        let savedToken = UserDefaults.standard.string(forKey: "dsh_bearer_token") ?? "change_this_to_a_long_random_secret"

        self.serverURL = savedURL
        self.bearerToken = savedToken

        let url = URL(string: savedURL) ?? URL(string: "http://localhost:3090")!
        self.client = ProxyClient(baseURL: url, bearerToken: savedToken)
    }

    private func updateClient() {
        if let url = URL(string: serverURL) {
            Task {
                await client.updateConfig(baseURL: url, bearerToken: bearerToken)
                await checkConnection()
            }
        }
    }

    // MARK: - Connection & Sessions

    public func checkConnection() async {
        do {
            self.isConnected = try await client.checkHealth()
            if self.isConnected {
                await loadSessions()
            }
        } catch {
            self.isConnected = false
            self.errorMessage = "Cannot connect to server: \(error.localizedDescription)"
        }
    }

    public func loadSessions() async {
        do {
            self.sessions = try await client.fetchSessions()
        } catch {
            self.errorMessage = "Failed to load sessions: \(error.localizedDescription)"
        }
    }

    public func createNewSession() async -> String? {
        do {
            let newId = try await client.createSession()
            await loadSessions()
            return newId
        } catch {
            self.errorMessage = "Failed to create session: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Chat & Streaming

    public func selectSession(_ sessionId: String) {
        guard activeSessionId != sessionId else { return }

        // Cancel existing stream
        streamTask?.cancel()
        streamTask = nil

        self.activeSessionId = sessionId
        self.messages = []
        self.lastReceivedSeq = -1
        self.isStreaming = false

        // Start streaming for this session
        startStream(sessionId: sessionId)
    }

    public func sendMessage(_ text: String) async {
        guard let sessionId = activeSessionId, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Optimistically append user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Create an empty assistant message slot for incoming chunks
        let assistantSlot = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantSlot)
        self.isStreaming = true

        do {
            _ = try await client.sendPrompt(sessionId: sessionId, text: text)
        } catch {
            self.errorMessage = "Failed to send message: \(error.localizedDescription)"
            self.isStreaming = false
            if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant && messages[lastIndex].content.isEmpty {
                messages.remove(at: lastIndex)
            }
        }
    }

    private func startStream(sessionId: String) {
        streamTask = Task {
            do {
                let stream = try await client.streamEvents(sessionId: sessionId, fromSeq: lastReceivedSeq)
                for await sse in stream {
                    if Task.isCancelled { break }
                    handleSSEEvent(sse)
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Stream disconnected: \(error.localizedDescription)"
                    self.isStreaming = false
                }
            }
        }
    }

    // MARK: - Event Dispatching

    private func handleSSEEvent(_ sse: SSEEvent) {
        if let idStr = sse.id, let seq = Int(idStr) {
            self.lastReceivedSeq = max(self.lastReceivedSeq, seq)
        }

        guard let data = sse.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String,
              let params = json["params"] as? [String: Any] else { return }

        switch method {
        case "session.status":
            if let status = params["status"] as? String {
                self.isStreaming = (status == "running")
                if status == "idle" {
                    finalizeCurrentStreamingMessage()
                }
            }

        case "session.event":
            guard let event = params["event"] as? [String: Any],
                  let eventType = event["type"] as? String else { return }
            handleSessionEvent(type: eventType, data: event["data"] as? [String: Any] ?? [:])

        default:
            break
        }
    }

    private func handleSessionEvent(type: String, data: [String: Any]) {
        switch type {
        case "assistant/chunk":
            // Live streaming chunk: append text to current assistant message
            if let chunk = data["chunk"] as? [String: Any],
               let text = chunk["text"] as? String {
                appendChunkToAssistant(text)
            }

        case "assistant/message":
            // Complete assistant message committed: finalize text
            if let message = data["message"] as? [String: Any],
               let contentArray = message["content"] as? [[String: Any]] {
                var fullText = ""
                for block in contentArray {
                    if block["type"] as? String == "text", let text = block["text"] as? String {
                        fullText += text
                    }
                }
                setAssistantMessageContent(fullText)
            }

        case "tool/call":
            // Tool execution started: append or update tool card
            let name = data["name"] as? String ?? "tool"
            let callId = data["callId"] as? String ?? UUID().uuidString
            let arguments = data["arguments"] as? String ?? "{}"
            let toolItem = ToolCallItem(id: callId, name: name, arguments: arguments, isExecuting: true)
            appendToolCallToAssistant(toolItem)

        case "tool/result":
            // Tool result returned: mark tool complete
            if let message = data["message"] as? [String: Any],
               let toolCallId = message["toolCallId"] as? String {
                let contentArray = message["content"] as? [[String: Any]] ?? []
                var resultText = ""
                for block in contentArray {
                    if let text = block["text"] as? String { resultText += text }
                }
                let hasError = data["error"] != nil
                updateToolResult(id: toolCallId, result: resultText, hasError: hasError)
            }

        case "approval/asked":
            // Agent asks for human confirmation
            let description = data["description"] as? String ?? "The agent requires permission to proceed."
            let toolName = data["tool"] as? String
            self.activeApproval = ApprovalRequest(sessionId: activeSessionId ?? "", toolName: toolName, description: description)

        default:
            break
        }
    }

    // MARK: - Message Mutation Helpers

    private func appendChunkToAssistant(_ text: String) {
        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages[lastIndex].content += text
            messages[lastIndex].isStreaming = true
        } else {
            let msg = ChatMessage(role: .assistant, content: text, isStreaming: true)
            messages.append(msg)
        }
    }

    private func setAssistantMessageContent(_ text: String) {
        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages[lastIndex].content = text
        } else {
            let msg = ChatMessage(role: .assistant, content: text, isStreaming: false)
            messages.append(msg)
        }
    }

    private func appendToolCallToAssistant(_ tool: ToolCallItem) {
        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages[lastIndex].toolCalls.append(tool)
        } else {
            let msg = ChatMessage(role: .assistant, content: "", toolCalls: [tool], isStreaming: true)
            messages.append(msg)
        }
    }

    private func updateToolResult(id: String, result: String, hasError: Bool) {
        for msgIndex in messages.indices {
            for toolIndex in messages[msgIndex].toolCalls.indices {
                if messages[msgIndex].toolCalls[toolIndex].id == id {
                    messages[msgIndex].toolCalls[toolIndex].result = result
                    messages[msgIndex].toolCalls[toolIndex].isExecuting = false
                    messages[msgIndex].toolCalls[toolIndex].hasError = hasError
                    return
                }
            }
        }
    }

    private func finalizeCurrentStreamingMessage() {
        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages[lastIndex].isStreaming = false
        }
        self.isStreaming = false
    }

    // MARK: - Approval

    public func resolveApproval(decision: String) async {
        guard let approval = activeApproval else { return }
        do {
            _ = try await client.submitApproval(sessionId: approval.sessionId, decision: decision)
            self.activeApproval = nil
        } catch {
            self.errorMessage = "Failed to submit approval: \(error.localizedDescription)"
        }
    }
}

//
//  Models.swift
//  DshMobile
//
//  Codable models for DeepSeek Harness Proxy API & SDK wire events.
//

import Foundation

// MARK: - Proxy API Responses

public struct SessionSummary: Codable, Identifiable {
    public let id: String
    public let status: String // "idle" | "running"
    public let createdAt: Double
    public let eventCount: Int

    public var isRunning: Bool { status == "running" }
    public var createdDate: Date { Date(timeIntervalSince1970: createdAt / 1000) }
}

public struct SessionsListResponse: Codable {
    public let sessions: [SessionSummary]
}

public struct CreateSessionResponse: Codable {
    public let sessionId: String
}

public struct PromptResponse: Codable {
    public let messageId: String
}

public struct SessionStatusResponse: Codable {
    public let status: String
    public let seq: Int
}

public struct ApproveResponse: Codable {
    public let ok: Bool
    public let decision: String
}

// MARK: - SDK Wire Events (SSE)

public struct SSEEnvelope: Codable {
    public let method: String
    public let params: [String: AnyCodable]
}

public struct SessionEventPayload: Codable {
    public let sessionId: String
    public let event: RawSessionEvent
}

public struct RawSessionEvent: Codable {
    public let type: String
    public let seq: Int?
    public let time: Double?
    public let data: [String: AnyCodable]?
}

// MARK: - UI Chat Message Models

public enum MessageRole: String, Codable {
    case user
    case assistant
    case tool
    case system
}

public struct ChatMessage: Identifiable, Equatable {
    public let id: String
    public let role: MessageRole
    public var content: String
    public var toolCalls: [ToolCallItem]
    public var isStreaming: Bool
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        toolCalls: [ToolCallItem] = [],
        isStreaming: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.isStreaming = isStreaming
        self.timestamp = timestamp
    }

    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content && lhs.isStreaming == rhs.isStreaming && lhs.toolCalls == rhs.toolCalls
    }
}

public struct ToolCallItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let arguments: String
    public var result: String?
    public var isExecuting: Bool
    public var hasError: Bool

    public init(
        id: String,
        name: String,
        arguments: String,
        result: String? = nil,
        isExecuting: Bool = true,
        hasError: Bool = false
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
        self.isExecuting = isExecuting
        self.hasError = hasError
    }
}

public struct ApprovalRequest: Identifiable {
    public let id: String
    public let sessionId: String
    public let toolName: String?
    public let description: String

    public init(id: String = UUID().uuidString, sessionId: String, toolName: String? = nil, description: String) {
        self.id = id
        self.sessionId = sessionId
        self.toolName = toolName
        self.description = description
    }
}

// MARK: - AnyCodable helper for heterogeneous JSON

public struct AnyCodable: Codable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported AnyCodable value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            let codableDict = dict.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case is NSNull:
            try container.encodeNil()
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode \(value)")
            throw EncodingError.invalidValue(value, context)
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

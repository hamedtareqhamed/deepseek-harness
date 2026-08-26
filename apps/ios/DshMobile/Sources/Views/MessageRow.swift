//
//  MessageRow.swift
//  DshMobile
//
//  Renders user message bubbles and assistant messages with streaming indicator and tool calls.
//

import SwiftUI

public struct MessageRow: View {
    public let message: ChatMessage

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Tool calls (if assistant performed actions)
                if !message.toolCalls.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.toolCalls) { tool in
                            ToolCallRow(tool: tool)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Message body text
                if !message.content.isEmpty {
                    Text(LocalizedStringKey(message.content))
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .background(message.role == .user ? Color.blue : Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .textSelection(.enabled)
                }

                // Streaming pulsing dot indicator
                if message.isStreaming && message.content.isEmpty && message.toolCalls.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

//
//  InputBar.swift
//  DshMobile
//
//  Bottom chat input bar with auto-expanding text editor and send button.
//

import SwiftUI

public struct InputBar: View {
    @Binding public var text: String
    public let isStreaming: Bool
    public let onSend: () -> Void

    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, isStreaming: Bool, onSend: @escaping () -> Void) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message DeepSeek Harness...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .focused($isFocused)

                Button(action: {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSend()
                    text = ""
                }) {
                    Image(systemName: isStreaming ? "circle.dotted" : "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(canSend ? .blue : .gray.opacity(0.5))
                }
                .disabled(!canSend || isStreaming)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

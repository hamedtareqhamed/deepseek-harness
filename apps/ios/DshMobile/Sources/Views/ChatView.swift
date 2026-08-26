//
//  ChatView.swift
//  DshMobile
//
//  Main conversation screen: scrollable message list with auto-scroll to bottom,
//  tool execution cards, approval modal binding, and input bar.
//

import SwiftUI

public struct ChatView: View {
    @EnvironmentObject private var state: AppState
    public let sessionId: String

    @State private var inputText: String = ""

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(state.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: state.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: state.messages.last?.content) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            InputBar(text: $inputText, isStreaming: state.isStreaming) {
                Task {
                    await state.sendMessage(inputText)
                }
            }
        }
        .navigationTitle(sessionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if state.isStreaming {
                    ProgressView()
                } else {
                    Circle()
                        .fill(state.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onAppear {
            state.selectSession(sessionId)
        }
        .sheet(item: $state.activeApproval) { approval in
            ApprovalSheet(approval: approval) { decision in
                Task {
                    await state.resolveApproval(decision: decision)
                }
            }
        }
    }

    private var sessionTitle: String {
        String(sessionId.prefix(12))
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = state.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

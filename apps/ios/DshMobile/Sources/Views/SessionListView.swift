//
//  SessionListView.swift
//  DshMobile
//
//  Lists all agent sessions from dsh-http-proxy, allows creating new sessions,
//  and navigates to ChatView.
//

import SwiftUI

public struct SessionListView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingSettings: Bool = false
    @State private var isCreatingSession: Bool = false
    @State private var selectedSessionId: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if state.sessions.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No sessions found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to start a new coding agent session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(state.sessions) { session in
                        NavigationLink(destination: ChatView(sessionId: session.id)) {
                            SessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("DeepSeek Harness")
            .refreshable {
                await state.loadSessions()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewSession) {
                        if isCreatingSession {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(isCreatingSession || !state.isConnected)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                await state.checkConnection()
            }
        }
    }

    private func createNewSession() {
        isCreatingSession = true
        Task {
            if let newId = await state.createNewSession() {
                selectedSessionId = newId
            }
            isCreatingSession = false
        }
    }
}

struct SessionRow: View {
    let session: SessionSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(session.isRunning ? Color.blue : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.id)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                Text(session.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(session.eventCount) events")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

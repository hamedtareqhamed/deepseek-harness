//
//  SettingsView.swift
//  DshMobile
//
//  Settings screen to configure Tailscale server URL and Bearer auth token.
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL: String = ""
    @State private var token: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Connection (Tailscale)")) {
                    TextField("http://100.x.x.x:3090", text: $serverURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)

                    SecureField("Bearer Token", text: $token)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            Text("Test Connection")
                            if isTesting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(state.isConnected ? .green : .red)
                    }
                }

                Section(footer: Text("DeepSeek Harness Mobile Client communicates over Tailscale with dsh-http-proxy on your host machine.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        state.serverURL = serverURL
                        state.bearerToken = token
                        dismiss()
                    }
                }
            }
            .onAppear {
                serverURL = state.serverURL
                token = state.bearerToken
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        state.serverURL = serverURL
        state.bearerToken = token

        Task {
            await state.checkConnection()
            isTesting = false
            testResult = state.isConnected ? "Successfully connected to DeepSeek Harness" : "Connection failed. Check Tailscale IP & Token."
        }
    }
}

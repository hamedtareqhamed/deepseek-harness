//
//  DshMobileApp.swift
//  DshMobile
//
//  Main application entrypoint.
//

import SwiftUI

@main
struct DshMobileApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SessionListView()
                .environmentObject(appState)
        }
    }
}

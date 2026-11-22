//
//  FollowDeckApp.swift
//  FollowDeck
//
//  App entry point. The full SwiftUI scene graph and dependency injection are wired
//  when the Xcode project is created on macOS.
//

import SwiftUI

@main
struct FollowDeckApp: App {
    // TODO(macOS): inject StoreProtocol, ReminderServiceProtocol, AIServiceProtocol here.
    @StateObject private var store = InMemoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

/// Placeholder root view — replaced by the real navigation (TodayBoard / Pipeline / Clients).
struct RootView: View {
    var body: some View {
        Text("FollowDeck")
            .font(.largeTitle)
    }
}

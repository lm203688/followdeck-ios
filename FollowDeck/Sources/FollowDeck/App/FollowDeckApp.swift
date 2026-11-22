//
//  FollowDeckApp.swift
//  FollowDeck
//
//  App entry point and composition root. The store bridge is injected here;
//  the wrapped persistence implementation is swapped for SwiftData in M1-2.
//

import SwiftUI

@main
struct FollowDeckApp: App {
    @StateObject private var bridge: StoreBridge

    init() {
        _bridge = StateObject(wrappedValue: StoreBridge(store: InMemoryStore()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bridge)
        }
    }
}

/// Root tab navigation: Today, Pipeline, Clients, Follow-ups.
struct RootView: View {
    var body: some View {
        TabView {
            TodayBoardView()
                .tabItem { Label("Today", systemImage: "checkmark.circle") }
            PipelineView()
                .tabItem { Label("Pipeline", systemImage: "rectangle.stack") }
            ClientsView()
                .tabItem { Label("Clients", systemImage: "person.2") }
            FollowUpsView()
                .tabItem { Label("Follow-ups", systemImage: "list.bullet") }
        }
    }
}

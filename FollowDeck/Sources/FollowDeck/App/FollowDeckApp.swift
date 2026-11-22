//
//  FollowDeckApp.swift
//  FollowDeck
//
//  App entry point and composition root. The shared SwiftData container lives in
//  PersistenceController; the StoreBridge wraps the store for SwiftUI observation.
//

import SwiftUI
import SwiftData

@main
struct FollowDeckApp: App {
    @StateObject private var bridge: StoreBridge

    init() {
        let store = PersistenceController.shared.makeStore()
        SampleData.seedIfEmpty(store: store)
        _bridge = StateObject(wrappedValue: StoreBridge(store: store))
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
        .onAppear {
            Task { try? await ReminderService.shared.requestAuthorization() }
        }
    }
}

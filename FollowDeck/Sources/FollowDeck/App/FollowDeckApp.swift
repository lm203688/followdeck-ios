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
    private enum Tab: Int, Hashable {
        case today, pipeline, clients, followUps
    }

    @State private var selectedTab: Tab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayBoardView()
                .tabItem { Label("Today", systemImage: "checkmark.circle") }
                .tag(Tab.today)
            PipelineView()
                .tabItem { Label("Pipeline", systemImage: "rectangle.stack") }
                .tag(Tab.pipeline)
            ClientsView()
                .tabItem { Label("Clients", systemImage: "person.2") }
                .tag(Tab.clients)
            FollowUpsView()
                .tabItem { Label("Follow-ups", systemImage: "list.bullet") }
                .tag(Tab.followUps)
        }
        .onAppear {
            Task { try? await ReminderService.shared.requestAuthorization() }
        }
        .onOpenURL { url in
            switch DeepLinkParser.target(for: url) {
            case .today: selectedTab = .today
            case .pipeline: selectedTab = .pipeline
            case .clients: selectedTab = .clients
            case .followUps: selectedTab = .followUps
            }
        }
    }
}

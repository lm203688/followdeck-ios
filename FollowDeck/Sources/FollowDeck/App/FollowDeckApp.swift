//
//  FollowDeckApp.swift
//  FollowDeck
//
//  App entry point and composition root. A local-first SwiftData ModelContainer is
//  built here; the StoreBridge wraps the SwiftData store for SwiftUI observation.
//

import SwiftUI
import SwiftData

@main
struct FollowDeckApp: App {
    @StateObject private var bridge: StoreBridge
    private let container: ModelContainer

    init() {
        do {
            let container = try ModelContainer(
                for: SDClient.self, SDDeal.self, SDFollowUp.self, SDInteraction.self
            )
            self.container = container
            let store = SwiftDataStore(context: container.mainContext)
            self._bridge = StateObject(wrappedValue: StoreBridge(store: store))
        } catch {
            fatalError("Unable to initialize SwiftData ModelContainer: \(error)")
        }
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

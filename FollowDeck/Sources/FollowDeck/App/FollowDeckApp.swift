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
    @StateObject private var subscriptions: SubscriptionManager

    init() {
        let store = PersistenceController.shared.makeStore()
        SampleData.seedIfEmpty(store: store)
        _bridge = StateObject(wrappedValue: StoreBridge(store: store))
        _subscriptions = StateObject(wrappedValue: SubscriptionManager())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bridge)
                .environmentObject(subscriptions)
                .onAppear { subscriptions.start() }
        }
    }
}

/// Root tab navigation: Today, Pipeline, Clients, Follow-ups.
struct RootView: View {
    private enum Tab: Int, Hashable {
        case today, pipeline, clients, followUps
    }

    @State private var selectedTab: Tab = RootView.launchTab

    /// Screenshot tooling opens a specific tab directly (`-uiTab=pipeline` etc.) instead of
    /// driving the UI, so App Store captures never depend on tap gestures or URL prompts.
    private static var launchTab: Tab {
        for arg in ProcessInfo.processInfo.arguments where arg.hasPrefix("-uiTab=") {
            switch arg.dropFirst("-uiTab=".count) {
            case "pipeline": return .pipeline
            case "clients": return .clients
            case "followups": return .followUps
            default: return .today
            }
        }
        return .today
    }

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
            // Screenshot runs must never surface a system permission alert over the UI.
            let isCaptureRun = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTab=") }
            guard !isCaptureRun else { return }
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

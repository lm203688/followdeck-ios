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
        #if DEBUG
        // Screenshot/preview runs open the paywall directly and render it from the
        // offline preview catalog; release builds always use the StoreKit service.
        let usePreviewStore = ProcessInfo.processInfo.arguments.contains("-uiTab=paywall")
        let service: SubscriptionServiceProtocol = usePreviewStore
            ? PreviewSubscriptionService() : StoreKitSubscriptionService()
        #else
        let service: SubscriptionServiceProtocol = StoreKitSubscriptionService()
        #endif
        _subscriptions = StateObject(wrappedValue: SubscriptionManager(service: service))
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
        case today, pipeline, clients, followUps, paywall
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
            case "paywall": return .paywall
            default: return .today
            }
        }
        return .today
    }

    /// Screenshot tooling can preselect a plan on the paywall (`-plan=monthly`
    /// or `-plan=yearly`) so one review frame can capture each product separately.
    private static var launchPlanID: String? {
        for arg in ProcessInfo.processInfo.arguments where arg.hasPrefix("-plan=") {
            switch arg.dropFirst("-plan=".count) {
            case "monthly": return ProductIDs.monthly
            case "yearly": return ProductIDs.yearly
            default: return nil
            }
        }
        return nil
    }

    var body: some View {
        if selectedTab == .paywall {
            ProPaywallView(initialPlanID: RootView.launchPlanID)
        } else {
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
}

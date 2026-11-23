//
//  WidgetSnapshotBuilder.swift
//  FollowDeck
//
//  Aggregates pending follow-ups into the glanceable widget summary and persists it to the
//  shared App Group. Pure Foundation logic over the store; no SwiftUI or network here.
//

import Foundation

enum WidgetSnapshotBuilder {
    static func snapshot(from store: StoreProtocol,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> WidgetSnapshot {
        let pending = store.pendingFollowUps()
        var overdue = 0
        var today = 0
        var upcoming = 0
        pending.forEach { followUp in
            switch RiskInsights.bucket(for: followUp, now: now, calendar: calendar) {
            case .overdue: overdue += 1
            case .today: today += 1
            case .upcoming: upcoming += 1
            }
        }
        let titles = pending.prefix(3).map(\.note)
        return WidgetSnapshot(
            overdueCount: overdue,
            todayCount: today,
            upcomingCount: upcoming,
            topTitles: titles,
            updatedAt: now
        )
    }

    /// Rebuild the shared snapshot and persist it for the widget to read.
    static func refresh(from store: StoreProtocol,
                        now: Date = Date(),
                        calendar: Calendar = .current) {
        WidgetSnapshotStore.save(snapshot(from: store, now: now, calendar: calendar))
    }
}

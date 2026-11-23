//
//  DashboardStats.swift
//  FollowDeck
//
//  Pure, portable aggregation for the glanceable summary: client count, open deals and the
//  pending follow-up buckets. No SwiftUI, persistence or network — tested off-device.
//

import Foundation

struct DashboardStats: Equatable {
    let clientCount: Int
    let openDealCount: Int
    let pendingFollowUpCount: Int
    let overdueCount: Int
    let todayCount: Int
    let upcomingCount: Int
}

enum DashboardStatsBuilder {
    static func stats(from store: StoreProtocol,
                      now: Date = Date(),
                      calendar: Calendar = .current) -> DashboardStats {
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

        let openDeals = store.allDeals().filter {
            $0.stage != .paid && $0.stage != .closed
        }

        return DashboardStats(
            clientCount: store.clients().count,
            openDealCount: openDeals.count,
            pendingFollowUpCount: pending.count,
            overdueCount: overdue,
            todayCount: today,
            upcomingCount: upcoming
        )
    }
}

//
//  RiskInsights.swift
//  FollowDeck
//
//  Pure, portable derivation of follow-up buckets and deal risk levels. No SwiftUI, no
//  persistence, no network — these helpers take model values and return a verdict so the
//  same rules can be unit-tested off-device.
//

import Foundation

/// Where a pending follow-up sits relative to today.
enum FollowUpBucket: Equatable {
    case overdue
    case today
    case upcoming
}

/// How urgent a deal looks based on stage and dwell time.
enum RiskLevel: String, Equatable {
    case none      // settled (paid / closed), nothing to chase
    case low       // fresh for its stage
    case medium    // drifting toward the stage threshold
    case high      // at-risk stage, or stalled past the threshold
}

/// Relative position of a follow-up's due date against today, in whole calendar days.
enum RelativeDue: Equatable {
    case overdue(days: Int)   // days > 0: how many days past the due date
    case today                // due later today
    case upcoming(days: Int)  // days > 0: how many days until it is due
}

struct DealRisk: Equatable {
    let daysStale: Int
    let level: RiskLevel
}

enum RiskInsights {
    /// Bucket a follow-up by its due date against the start of today.
    static func bucket(for followUp: FollowUp,
                       now: Date = Date(),
                       calendar: Calendar = .current) -> FollowUpBucket {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        if followUp.dueAt < startOfToday { return .overdue }
        if followUp.dueAt < startOfTomorrow { return .today }
        return .upcoming
    }

    /// Whole-calendar-day gap between a due date and today: negative means overdue,
    /// zero means today, positive means upcoming. Day boundaries follow the given calendar.
    static func relativeDue(for dueAt: Date,
                            now: Date = Date(),
                            calendar: Calendar = .current) -> RelativeDue {
        let dueDay = calendar.startOfDay(for: dueAt)
        let todayDay = calendar.startOfDay(for: now)
        let diff = calendar.dateComponents([.day], from: todayDay, to: dueDay).day ?? 0
        if diff < 0 { return .overdue(days: -diff) }
        if diff == 0 { return .today }
        return .upcoming(days: diff)
    }

    /// Derive dwell time and risk level for a deal.
    static func risk(for deal: Deal,
                     now: Date = Date(),
                     calendar: Calendar = .current) -> DealRisk {
        let daysStale = max(0, calendar.dateComponents([.day], from: deal.updatedAt, to: now).day ?? 0)

        if deal.stage == .paid || deal.stage == .closed {
            return DealRisk(daysStale: daysStale, level: .none)
        }
        if deal.stage == .atRisk {
            return DealRisk(daysStale: daysStale, level: .high)
        }

        let threshold = max(deal.stage.defaultFollowUpOffsetDays, 3)
        let level: RiskLevel
        if daysStale > threshold {
            level = .high
        } else if daysStale > threshold / 2 {
            level = .medium
        } else {
            level = .low
        }
        return DealRisk(daysStale: daysStale, level: level)
    }
}

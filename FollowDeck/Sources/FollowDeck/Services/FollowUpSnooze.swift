//
//  FollowUpSnooze.swift
//  FollowDeck
//
//  Pure, portable snooze derivation: pick a delay bucket, mark the follow-up as
//  snoozed and push its due date forward by that many calendar days. No SwiftUI,
//  persistence or network — tested off-device.
//

import Foundation

/// A snooze delay bucket offered in the follow-up row menu.
enum SnoozeOption: String, CaseIterable, Identifiable {
    case tomorrow
    case threeDays
    case week

    var id: String { rawValue }

    /// Calendar days to push the due date forward.
    var days: Int {
        switch self {
        case .tomorrow: 1
        case .threeDays: 3
        case .week: 7
        }
    }

    /// English menu label.
    var title: String {
        switch self {
        case .tomorrow: "Tomorrow"
        case .threeDays: "In 3 days"
        case .week: "In a week"
        }
    }
}

enum FollowUpSnooze {
    /// Return a copy of the follow-up marked snoozed, with its due date moved
    /// `option.days` days forward from `now`. All other fields are preserved.
    static func snoozing(_ followUp: FollowUp,
                         option: SnoozeOption,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> FollowUp {
        var updated = followUp
        updated.status = .snoozed
        updated.dueAt = calendar.date(byAdding: .day, value: option.days, to: now) ?? now
        return updated
    }
}

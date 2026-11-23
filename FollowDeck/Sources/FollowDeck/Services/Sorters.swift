//
//  Sorters.swift
//  FollowDeck
//
//  Pure, portable default ordering for the roster and follow-up list. No SwiftUI,
//  persistence or network — tested off-device. Views wrap the store results here.
//

import Foundation

enum ClientSorter {
    /// Alphabetical by name (case- and diacritic-insensitive); ties break by creation date.
    static func sorted(_ clients: [Client]) -> [Client] {
        clients.sorted { a, b in
            let nameA = a.name.localizedLowercase
            let nameB = b.name.localizedLowercase
            if nameA != nameB { return nameA < nameB }
            return a.createdAt < b.createdAt
        }
    }
}

enum FollowUpSorter {
    /// Pending / snoozed items come first, ordered by due date ascending; completed items
    /// follow, ordered by completion time descending.
    static func sorted(_ items: [FollowUp]) -> [FollowUp] {
        items.sorted { a, b in
            let rankA = rank(a.status)
            let rankB = rank(b.status)
            if rankA != rankB { return rankA < rankB }
            if a.status == .done {
                return (a.completedAt ?? a.createdAt) > (b.completedAt ?? b.createdAt)
            }
            return a.dueAt < b.dueAt
        }
    }

    private static func rank(_ status: FollowUpStatus) -> Int {
        status == .done ? 1 : 0
    }
}

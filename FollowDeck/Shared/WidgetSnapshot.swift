//
//  WidgetSnapshot.swift
//  FollowDeckShared
//
//  Cross-target summary written by the main app and read by the widget extension. The data
//  stays local: it travels through the shared App Group container, never over the network.
//

import Foundation

/// A point-in-time summary of pending follow-ups, formatted for a glanceable widget.
struct WidgetSnapshot: Codable, Equatable {
    var overdueCount: Int
    var todayCount: Int
    var upcomingCount: Int
    var topTitles: [String]
    var updatedAt: Date
}

enum WidgetSnapshotStore {
    /// Must match the `com.apple.security.application-groups` entitlement on both targets.
    static let suiteName = "group.com.lixing.followdeck"
    private static let key = "followdeck.widget-snapshot"

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}

//
//  ClientMatcher.swift
//  FollowDeck
//
//  Pure filtering logic for the client roster search. Portable Foundation logic so the
//  match rules can be unit-tested without a running UI.
//

import Foundation

/// Case-insensitive substring matching across a client's searchable fields.
enum ClientMatcher {

    /// Returns true when the query (trimmed, lowercased) appears in any searchable
    /// field. An empty / whitespace-only query matches every client.
    static func matches(_ client: Client, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }

        let fields = [
            client.name,
            client.email ?? "",
            client.phone ?? "",
            client.tags.joined(separator: " ")
        ]
        return fields.contains { $0.lowercased().contains(needle) }
    }

    /// Filters the roster, preserving the caller-provided order.
    static func filter(_ clients: [Client], query: String) -> [Client] {
        clients.filter { matches($0, query: query) }
    }
}

//
//  ProductIDs.swift
//  FollowDeck
//
//  App Store Connect product identifiers for the FollowDeck Pro subscription
//  group. These mirror the draft entries created in App Store Connect and must
//  match the product IDs registered there exactly (lowercase letters, digits, dots).
//

import Foundation

enum ProductIDs {
    /// Monthly auto-renewing subscription.
    static let monthly = "com.lixing.followdeck.pro.monthly"
    /// Yearly auto-renewing subscription (carries the 7-day free trial).
    static let yearly = "com.lixing.followdeck.pro.yearly"

    /// Every Pro product ID in the subscription group.
    static let all: [String] = [monthly, yearly]

    /// Whether the given product ID belongs to the FollowDeck Pro group.
    static func isProProduct(_ productID: String) -> Bool {
        all.contains(productID)
    }
}

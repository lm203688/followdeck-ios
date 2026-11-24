//
//  PaywallPlan.swift
//  FollowDeck
//
//  Pure, portable presentation rules for the FollowDeck Pro paywall. No StoreKit
//  or SwiftUI dependency: period copy, free-trial length, the recommended plan and
//  the Pro feature list are derived deterministically from the known product IDs,
//  so paywall ordering and copy can be verified off-device on the CI runner.
//

import Foundation

/// A subscription plan prepared for display on the Pro paywall.
struct PaywallPlan: Identifiable, Equatable {
    /// App Store Connect product ID.
    let id: String
    /// Localized store name.
    let name: String
    /// Localized price string (e.g. "$29.99").
    let priceDisplay: String
    /// Human-readable subscription period (e.g. "1 year").
    let period: String
    /// Free-trial length in days; nil when the plan has no trial.
    let trialFreeDays: Int?
    /// Whether this plan is the recommended best-value option.
    let isRecommended: Bool

    /// Trial marketing copy; nil when the plan has no trial.
    var trialCopy: String? {
        guard let days = trialFreeDays else { return nil }
        return "\(days)-day free trial"
    }
}

enum PaywallCatalog {
    /// The yearly plan carries a 7-day free trial; the monthly plan has none.
    static let yearlyFreeTrialDays = 7

    /// Pro feature highlights shown on the paywall. Mirrors the ASC subscription
    /// description: "Unlimited clients, sequences, templates and reports."
    static let proFeatures: [String] = [
        "Unlimited clients",
        "Unlimited sequences",
        "Unlimited templates",
        "Unlimited reports",
    ]

    /// Deterministic period copy for a known Pro product ID.
    static func period(for productID: String) -> String {
        switch productID {
        case ProductIDs.monthly: return "1 month"
        case ProductIDs.yearly: return "1 year"
        default: return ""
        }
    }

    /// Free-trial length in days; only the yearly plan includes the trial.
    static func trialFreeDays(for productID: String) -> Int? {
        productID == ProductIDs.yearly ? yearlyFreeTrialDays : nil
    }

    /// The yearly plan is the recommended best-value option.
    static func isRecommended(_ productID: String) -> Bool {
        productID == ProductIDs.yearly
    }

    /// Map a store display product to its paywall plan, filling period, trial and
    /// recommendation from the deterministic catalog rules.
    static func plan(from product: DisplayProduct) -> PaywallPlan {
        PaywallPlan(
            id: product.id,
            name: product.name,
            priceDisplay: product.priceDisplay,
            period: period(for: product.id),
            trialFreeDays: trialFreeDays(for: product.id),
            isRecommended: isRecommended(product.id)
        )
    }

    /// Recommended paywall order: the yearly best-value plan first, then monthly.
    static func sorted(_ plans: [PaywallPlan]) -> [PaywallPlan] {
        plans.sorted { lhs, rhs in
            if lhs.isRecommended != rhs.isRecommended { return lhs.isRecommended }
            return lhs.id < rhs.id
        }
    }
}

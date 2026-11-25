//
//  Entitlement.swift
//  FollowDeck
//
//  Pure, portable subscription entitlement and free-tier gating rules. This file
//  has no StoreKit dependency: the active subscription identifiers are supplied
//  by whatever receipt/transaction layer validates them, so the rules can be
//  tested off-device on the macOS CI runner.
//

import Foundation

/// The access tier resolved for the current install.
enum Entitlement: Equatable {
    /// Free tier: capped roster, core follow-up features only.
    case free
    /// Pro: unlimited client roster.
    case pro
}

enum EntitlementPolicy {
    /// The free tier allows this many clients; Pro removes the cap.
    static let freeTierClientLimit = 20

    /// Resolve the tier from the set of currently active Pro product identifiers.
    /// Any active product from the FollowDeck Pro group upgrades the install to Pro.
    static func entitlement(activeProductIDs: Set<String>) -> Entitlement {
        activeProductIDs.contains(where: ProductIDs.isProProduct) ? .pro : .free
    }

    /// Whether a new client may be added under the current entitlement.
    /// Pro is uncapped; free stops at `freeTierClientLimit`.
    static func canAddClient(currentClientCount: Int, entitlement: Entitlement) -> Bool {
        guard entitlement == .free else { return true }
        return currentClientCount < freeTierClientLimit
    }
}

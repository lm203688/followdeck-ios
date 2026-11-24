//
//  PaywallPresentation.swift
//  FollowDeck
//
//  Pure, portable assembly model for the Pro paywall. This layer turns the store
//  products loaded by the subscription service into ready-to-display plan groups,
//  the recommended best-value plan and the Pro feature list. It has no StoreKit or
//  SwiftUI dependency, so the ordering, filtering and fallback rules can be
//  verified off-device on the CI runner. The paywall view and purchase button are
//  created in the Pro batch; this file supplies only the data they will consume.
//

import Foundation

/// Ready-to-display paywall content, assembled from the loaded store products.
struct PaywallPresentation: Equatable {
    /// Sorted plans for the store, best-value first.
    let plans: [PaywallPlan]
    /// The recommended best-value plan, when one is available.
    let recommended: PaywallPlan?
    /// Pro feature highlights shown on the paywall.
    let features: [String]

    /// Whether at least one plan loaded; the UI shows a store-unavailable fallback
    /// when the product request returned nothing.
    var hasPlans: Bool { !plans.isEmpty }
}

/// Assembles paywall presentation models from store products, reusing the
/// deterministic catalog rules in `PaywallCatalog`.
enum PaywallAssembly {
    /// Build a presentation from the products loaded by the subscription service.
    /// Unknown (non-Pro) product IDs are dropped; when no Pro product loaded the
    /// result carries an empty plan list but still exposes the Pro feature list.
    static func presentation(products: [DisplayProduct]) -> PaywallPresentation {
        let plans = PaywallCatalog.sorted(
            products
                .filter { ProductIDs.isProProduct($0.id) }
                .map { PaywallCatalog.plan(from: $0) }
        )
        return PaywallPresentation(
            plans: plans,
            recommended: plans.first(where: { $0.isRecommended }),
            features: PaywallCatalog.proFeatures
        )
    }
}

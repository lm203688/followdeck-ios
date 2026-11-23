//
//  PipelineSummary.swift
//  FollowDeck
//
//  Pure, portable aggregation for the pipeline header: open deal count, priced deal count
//  and amounts grouped by currency. Paid/closed deals are excluded from the open pipeline.
//  No SwiftUI, persistence or network — tested off-device.
//

import Foundation

struct PipelineSummary: Equatable {
    /// Deals still in flight (excluding paid and closed).
    let openDealCount: Int
    /// Open deals that carry a recorded amount.
    let pricedDealCount: Int
    /// Amount totals keyed by currency code.
    let amountByCurrency: [String: Decimal]
    /// Currency used for the headline total; the currency of the first priced open deal.
    let primaryCurrency: String?

    /// Headline total for the primary currency; nil when no open deal has a priced amount.
    var totalAmount: Decimal? {
        guard let primaryCurrency else { return nil }
        return amountByCurrency[primaryCurrency]
    }
}

enum PipelineSummaryBuilder {
    static func summary(from deals: [Deal]) -> PipelineSummary {
        let openDeals = deals.filter { $0.stage != .paid && $0.stage != .closed }

        var byCurrency: [String: Decimal] = [:]
        var priced = 0
        var primaryCurrency: String?

        openDeals.forEach { deal in
            guard let amount = deal.amount else { return }
            priced += 1
            byCurrency[deal.currency, default: 0] += amount
            if primaryCurrency == nil {
                primaryCurrency = deal.currency
            }
        }

        return PipelineSummary(
            openDealCount: openDeals.count,
            pricedDealCount: priced,
            amountByCurrency: byCurrency,
            primaryCurrency: primaryCurrency
        )
    }
}

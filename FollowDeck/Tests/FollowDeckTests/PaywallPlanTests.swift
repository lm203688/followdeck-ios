//
//  PaywallPlanTests.swift
//  FollowDeckTests
//
//  Verify the paywall presentation rules off-device: period copy, the yearly-only
//  7-day trial, the yearly best-value recommendation, feature list, mapping and
//  recommended ordering. No StoreKit dependency is exercised here.
//

import XCTest
@testable import FollowDeck

final class PaywallPlanTests: XCTestCase {

    private func makeProduct(_ id: String, name: String, price: String) -> DisplayProduct {
        DisplayProduct(id: id, name: name, priceDisplay: price, period: "")
    }

    func testMonthlyPeriodCopy() {
        XCTAssertEqual(PaywallCatalog.period(for: ProductIDs.monthly), "1 month")
    }

    func testYearlyPeriodCopy() {
        XCTAssertEqual(PaywallCatalog.period(for: ProductIDs.yearly), "1 year")
    }

    func testUnknownProductHasEmptyPeriod() {
        XCTAssertEqual(PaywallCatalog.period(for: "com.other.app.plus"), "")
    }

    func testOnlyYearlyCarriesTrial() {
        XCTAssertEqual(PaywallCatalog.trialFreeDays(for: ProductIDs.yearly), 7)
        XCTAssertNil(PaywallCatalog.trialFreeDays(for: ProductIDs.monthly))
        XCTAssertNil(PaywallCatalog.trialFreeDays(for: "com.other.app.plus"))
    }

    func testYearlyIsRecommended() {
        XCTAssertTrue(PaywallCatalog.isRecommended(ProductIDs.yearly))
        XCTAssertFalse(PaywallCatalog.isRecommended(ProductIDs.monthly))
    }

    func testTrialCopy() {
        let yearly = PaywallCatalog.plan(from: makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99"))
        XCTAssertEqual(yearly.trialCopy, "7-day free trial")

        let monthly = PaywallCatalog.plan(from: makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99"))
        XCTAssertNil(monthly.trialCopy)
    }

    func testProFeaturesMirrorSubscriptionDescription() {
        XCTAssertEqual(PaywallCatalog.proFeatures, [
            "Unlimited clients",
            "Unlimited sequences",
            "Unlimited templates",
            "Unlimited reports",
        ])
    }

    func testPlanMappingPreservesStoreFields() {
        let product = makeProduct(ProductIDs.yearly, name: "FollowDeck Pro Yearly", price: "$29.99")
        let plan = PaywallCatalog.plan(from: product)

        XCTAssertEqual(plan.id, ProductIDs.yearly)
        XCTAssertEqual(plan.name, "FollowDeck Pro Yearly")
        XCTAssertEqual(plan.priceDisplay, "$29.99")
        XCTAssertEqual(plan.period, "1 year")
        XCTAssertEqual(plan.trialFreeDays, 7)
        XCTAssertTrue(plan.isRecommended)
    }

    func testRecommendedOrderingPutsYearlyFirst() {
        let monthly = PaywallCatalog.plan(from: makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99"))
        let yearly = PaywallCatalog.plan(from: makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99"))

        let sorted = PaywallCatalog.sorted([monthly, yearly])
        XCTAssertEqual(sorted.map(\.id), [ProductIDs.yearly, ProductIDs.monthly])
    }
}

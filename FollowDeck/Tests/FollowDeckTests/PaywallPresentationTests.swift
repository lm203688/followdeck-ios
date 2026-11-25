//
//  PaywallPresentationTests.swift
//  FollowDeckTests
//
//  Verify the paywall assembly model off-device: plan ordering, recommendation
//  selection, non-Pro filtering, empty-product fallback and carried trial flags.
//  No StoreKit dependency is exercised here.
//

import XCTest
@testable import FollowDeck

final class PaywallPresentationTests: XCTestCase {

    private func makeProduct(_ id: String, name: String, price: String) -> DisplayProduct {
        DisplayProduct(id: id, name: name, priceDisplay: price, period: "")
    }

    func testAssemblyOrdersYearlyFirstRegardlessOfInputOrder() {
        let products = [
            makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99"),
            makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99"),
        ]

        let presentation = PaywallAssembly.presentation(products: products)
        XCTAssertEqual(presentation.plans.map(\.id), [ProductIDs.yearly, ProductIDs.monthly])
        XCTAssertTrue(presentation.hasPlans)
    }

    func testAssemblyRecommendsYearlyPlan() {
        let products = [
            makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99"),
            makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99"),
        ]

        let presentation = PaywallAssembly.presentation(products: products)
        XCTAssertEqual(presentation.recommended?.id, ProductIDs.yearly)
        XCTAssertEqual(presentation.recommended?.id, presentation.plans.first?.id)
    }

    func testAssemblyExposesProFeatureList() {
        let products = [makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99")]
        let presentation = PaywallAssembly.presentation(products: products)

        XCTAssertEqual(presentation.features, PaywallCatalog.proFeatures)
        XCTAssertEqual(presentation.features.count, PaywallCatalog.proFeatures.count)
    }

    func testEmptyProductsKeepFeaturesButNoPlans() {
        let presentation = PaywallAssembly.presentation(products: [])

        XCTAssertFalse(presentation.hasPlans)
        XCTAssertEqual(presentation.plans, [])
        XCTAssertNil(presentation.recommended)
        XCTAssertEqual(presentation.features, PaywallCatalog.proFeatures)
    }

    func testAssemblyFiltersOutNonProProducts() {
        let products = [
            makeProduct("com.other.app.plus", name: "Other", price: "$1.99"),
            makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99"),
            makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99"),
        ]

        let presentation = PaywallAssembly.presentation(products: products)
        XCTAssertEqual(presentation.plans.map(\.id), [ProductIDs.yearly, ProductIDs.monthly])
    }

    func testMonthlyOnlyHasNoRecommendedPlan() {
        let products = [makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99")]
        let presentation = PaywallAssembly.presentation(products: products)

        XCTAssertEqual(presentation.plans.map(\.id), [ProductIDs.monthly])
        XCTAssertNil(presentation.recommended)
    }

    func testAssemblyCarriesTrialAndRecommendationFlags() {
        let products = [
            makeProduct(ProductIDs.monthly, name: "Pro Monthly", price: "$4.99"),
            makeProduct(ProductIDs.yearly, name: "Pro Yearly", price: "$29.99"),
        ]

        let presentation = PaywallAssembly.presentation(products: products)
        let yearly = presentation.plans.first { $0.id == ProductIDs.yearly }
        let monthly = presentation.plans.first { $0.id == ProductIDs.monthly }

        XCTAssertEqual(yearly?.trialFreeDays, 7)
        XCTAssertTrue(yearly?.isRecommended ?? false)
        XCTAssertNil(monthly?.trialFreeDays)
        XCTAssertFalse(monthly?.isRecommended ?? true)
    }
}

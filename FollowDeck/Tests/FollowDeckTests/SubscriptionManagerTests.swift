//
//  SubscriptionManagerTests.swift
//  FollowDeckTests
//
//  Verify the manager's entitlement mirroring and purchase/restore state flow with a
//  mock subscription service. No StoreKit session, product or transaction is touched;
//  the mock stands in for the store backend so the state machine is testable off-device.
//

import XCTest
@testable import FollowDeck

private final class MockSubscriptionService: SubscriptionServiceProtocol {
    var stubbedActive: Set<String> = []
    var stubbedProducts: [DisplayProduct] = []
    var purchaseResult: Set<String> = []
    var purchaseError: Error?
    var purchasedProductIDs: [String] = []
    var restoreCalled = false

    func loadProducts() async throws -> [DisplayProduct] { stubbedProducts }

    func purchase(productID: String) async throws -> Set<String> {
        purchasedProductIDs.append(productID)
        if let purchaseError { throw purchaseError }
        return purchaseResult
    }

    func restorePurchases() async throws -> Set<String> {
        restoreCalled = true
        return stubbedActive
    }

    func activeProductIDs() async -> Set<String> { stubbedActive }

    func updates() -> AsyncStream<Set<String>> {
        AsyncStream { $0.finish() }
    }
}

@MainActor
final class SubscriptionManagerTests: XCTestCase {

    private func makeManager() -> (SubscriptionManager, MockSubscriptionService) {
        let mock = MockSubscriptionService()
        let manager = SubscriptionManager(service: mock)
        return (manager, mock)
    }

    func testSuccessfulPurchaseGrantsPro() async {
        let (manager, mock) = makeManager()
        mock.purchaseResult = [ProductIDs.yearly]

        await manager.performPurchase(productID: ProductIDs.yearly)

        XCTAssertEqual(mock.purchasedProductIDs, [ProductIDs.yearly])
        XCTAssertEqual(manager.entitlement, .pro)
        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(manager.message, "Welcome to FollowDeck Pro.")
        XCTAssertFalse(manager.isPurchasing)
    }

    func testCancelledPurchaseStaysFree() async {
        let (manager, mock) = makeManager()
        mock.purchaseError = SubscriptionError.userCancelled

        await manager.performPurchase(productID: ProductIDs.monthly)

        XCTAssertEqual(manager.entitlement, .free)
        XCTAssertEqual(manager.message, "Purchase cancelled.")
        XCTAssertFalse(manager.isPurchasing)
    }

    func testFailedPurchaseKeepsFreeAndReportsError() async {
        let (manager, mock) = makeManager()
        mock.purchaseError = SubscriptionError.unverifiedTransaction

        await manager.performPurchase(productID: ProductIDs.yearly)

        XCTAssertEqual(manager.entitlement, .free)
        XCTAssertEqual(manager.message, "Could not complete purchase. Please try again.")
        XCTAssertFalse(manager.isPurchasing)
    }

    func testRestorePurchasesGrantsPro() async {
        let (manager, mock) = makeManager()
        mock.stubbedActive = [ProductIDs.monthly]

        await manager.performRestore()

        XCTAssertTrue(mock.restoreCalled)
        XCTAssertEqual(manager.entitlement, .pro)
        XCTAssertEqual(manager.message, "Purchases restored.")
        XCTAssertFalse(manager.isRestoring)
    }

    func testRestoreWithNoActiveSubscriptionStaysFree() async {
        let (manager, mock) = makeManager()
        mock.stubbedActive = []

        await manager.performRestore()

        XCTAssertEqual(manager.entitlement, .free)
        XCTAssertEqual(manager.message, "No active subscription found.")
        XCTAssertFalse(manager.isRestoring)
    }

    func testReloadPublishesStoreProducts() async {
        let (manager, mock) = makeManager()
        mock.stubbedProducts = [
            DisplayProduct(id: ProductIDs.monthly, name: "Pro Monthly", priceDisplay: "$4.99", period: "1 month"),
            DisplayProduct(id: ProductIDs.yearly, name: "Pro Yearly", priceDisplay: "$29.99", period: "1 year")
        ]

        await manager.reload()

        XCTAssertEqual(manager.products.map(\.id), [ProductIDs.monthly, ProductIDs.yearly])
    }

    func testReloadAssemblesPaywallPresentation() async {
        let (manager, mock) = makeManager()
        mock.stubbedProducts = [
            DisplayProduct(id: ProductIDs.monthly, name: "Pro Monthly", priceDisplay: "$4.99", period: "1 month"),
            DisplayProduct(id: ProductIDs.yearly, name: "Pro Yearly", priceDisplay: "$29.99", period: "1 year")
        ]

        await manager.reload()

        let presentation = manager.presentation
        XCTAssertEqual(presentation.plans.map(\.id), [ProductIDs.yearly, ProductIDs.monthly])
        XCTAssertEqual(presentation.recommended?.id, ProductIDs.yearly)
        XCTAssertTrue(presentation.hasPlans)
        XCTAssertEqual(presentation.features, PaywallCatalog.proFeatures)
    }

    func testEmptyProductsPresentationHasNoPlans() async {
        let (manager, mock) = makeManager()
        mock.stubbedProducts = []

        await manager.reload()

        let presentation = manager.presentation
        XCTAssertFalse(presentation.hasPlans)
        XCTAssertEqual(presentation.plans, [])
        XCTAssertNil(presentation.recommended)
        XCTAssertEqual(presentation.features, PaywallCatalog.proFeatures)
    }

    func testPreviewServiceServesBothCatalogProductsAndStaysFree() async {
        let preview = PreviewSubscriptionService()
        let products = try await preview.loadProducts()

        XCTAssertEqual(products.map(\.id), [ProductIDs.monthly, ProductIDs.yearly])
        XCTAssertEqual(products.first?.priceDisplay, "$4.99")
        XCTAssertEqual(products.last?.priceDisplay, "$29.99")
        XCTAssertTrue(await preview.activeProductIDs().isEmpty)
    }
}

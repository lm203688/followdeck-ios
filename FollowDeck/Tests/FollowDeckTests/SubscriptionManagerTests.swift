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

final class SubscriptionManagerTests: XCTestCase {

    @MainActor
    private func makeManager() -> (SubscriptionManager, MockSubscriptionService) {
        let mock = MockSubscriptionService()
        let manager = SubscriptionManager(service: mock)
        return (manager, mock)
    }

    @MainActor
    private func wait(_ condition: @escaping () -> Bool, timeout: TimeInterval = 3) async {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("timed out waiting for condition")
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func testSuccessfulPurchaseGrantsPro() async {
        await MainActor.run {
            let (manager, mock) = makeManager()
            mock.purchaseResult = [ProductIDs.yearly]

            manager.purchase(productID: ProductIDs.yearly)
            await wait { manager.isPurchasing == false }

            XCTAssertEqual(mock.purchasedProductIDs, [ProductIDs.yearly])
            XCTAssertEqual(manager.entitlement, .pro)
            XCTAssertTrue(manager.isPro)
            XCTAssertEqual(manager.message, "Welcome to FollowDeck Pro.")
        }
    }

    func testCancelledPurchaseStaysFree() async {
        await MainActor.run {
            let (manager, mock) = makeManager()
            mock.purchaseError = SubscriptionError.userCancelled

            manager.purchase(productID: ProductIDs.monthly)
            await wait { manager.isPurchasing == false }

            XCTAssertEqual(manager.entitlement, .free)
            XCTAssertEqual(manager.message, "Purchase cancelled.")
        }
    }

    func testFailedPurchaseKeepsFreeAndReportsError() async {
        await MainActor.run {
            let (manager, mock) = makeManager()
            mock.purchaseError = SubscriptionError.unverifiedTransaction

            manager.purchase(productID: ProductIDs.yearly)
            await wait { manager.isPurchasing == false }

            XCTAssertEqual(manager.entitlement, .free)
            XCTAssertEqual(manager.message, "Could not complete purchase. Please try again.")
        }
    }

    func testRestorePurchasesGrantsPro() async {
        await MainActor.run {
            let (manager, mock) = makeManager()
            mock.stubbedActive = [ProductIDs.monthly]

            manager.restorePurchases()
            await wait { manager.isRestoring == false }

            XCTAssertTrue(mock.restoreCalled)
            XCTAssertEqual(manager.entitlement, .pro)
            XCTAssertEqual(manager.message, "Purchases restored.")
        }
    }

    func testRestoreWithNoActiveSubscriptionStaysFree() async {
        await MainActor.run {
            let (manager, mock) = makeManager()
            mock.stubbedActive = []

            manager.restorePurchases()
            await wait { manager.isRestoring == false }

            XCTAssertEqual(manager.entitlement, .free)
            XCTAssertEqual(manager.message, "No active subscription found.")
        }
    }

    func testReloadPublishesStoreProducts() async {
        await MainActor.run {
            let (manager, mock) = makeManager()
            mock.stubbedProducts = [
                DisplayProduct(id: ProductIDs.monthly, name: "Pro Monthly", priceDisplay: "$4.99", period: "1 month"),
                DisplayProduct(id: ProductIDs.yearly, name: "Pro Yearly", priceDisplay: "$29.99", period: "1 year")
            ]

            await manager.reload()

            XCTAssertEqual(manager.products.map(\.id), [ProductIDs.monthly, ProductIDs.yearly])
        }
    }
}

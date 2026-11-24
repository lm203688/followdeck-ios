//
//  EntitlementTests.swift
//  FollowDeckTests
//
//  Verify the entitlement resolution and free-tier roster cap without any
//  StoreKit dependency: active Pro product IDs resolve to Pro, everything else
//  falls back to free, and only Pro removes the 20-client cap.
//

import XCTest
@testable import FollowDeck

final class EntitlementTests: XCTestCase {

    func testNoActiveProductsResolveToFree() {
        XCTAssertEqual(EntitlementPolicy.entitlement(activeProductIDs: []), .free)
    }

    func testMonthlyProductIsPro() {
        XCTAssertEqual(
            EntitlementPolicy.entitlement(activeProductIDs: [ProductIDs.monthly]),
            .pro
        )
    }

    func testYearlyProductIsPro() {
        XCTAssertEqual(
            EntitlementPolicy.entitlement(activeProductIDs: [ProductIDs.yearly]),
            .pro
        )
    }

    func testUnknownProductDoesNotGrantPro() {
        XCTAssertEqual(
            EntitlementPolicy.entitlement(activeProductIDs: ["com.other.app.plus"]),
            .free
        )
    }

    func testProductIDMembership() {
        XCTAssertTrue(ProductIDs.isProProduct(ProductIDs.monthly))
        XCTAssertTrue(ProductIDs.isProProduct(ProductIDs.yearly))
        XCTAssertFalse(ProductIDs.isProProduct("com.lixing.followdeck.legacy"))
    }

    func testFreeTierStopsAtClientLimit() {
        let limit = EntitlementPolicy.freeTierClientLimit
        XCTAssertTrue(EntitlementPolicy.canAddClient(currentClientCount: limit - 1, entitlement: .free))
        XCTAssertFalse(EntitlementPolicy.canAddClient(currentClientCount: limit, entitlement: .free))
        XCTAssertFalse(EntitlementPolicy.canAddClient(currentClientCount: limit + 5, entitlement: .free))
    }

    func testProIsUncapped() {
        XCTAssertTrue(EntitlementPolicy.canAddClient(currentClientCount: 0, entitlement: .pro))
        XCTAssertTrue(EntitlementPolicy.canAddClient(currentClientCount: 100, entitlement: .pro))
    }
}

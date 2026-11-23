//
//  PipelineSummaryBuilderTests.swift
//  FollowDeckTests
//
//  Verify pipeline open-deal counting and amount aggregation: paid/closed are excluded,
//  amounts are summed per currency, and the headline total follows the primary currency.
//

import XCTest
@testable import FollowDeck

final class PipelineSummaryBuilderTests: XCTestCase {

    private func makeDeal(stage: DealStage, amount: Decimal? = nil, currency: String = "USD") -> Deal {
        Deal(clientID: UUID(), title: "Deal", stage: stage, amount: amount, currency: currency)
    }

    func testEmptyPipelineIsZeroedWithNoTotal() {
        let summary = PipelineSummaryBuilder.summary(from: [])

        XCTAssertEqual(summary.openDealCount, 0)
        XCTAssertEqual(summary.pricedDealCount, 0)
        XCTAssertTrue(summary.amountByCurrency.isEmpty)
        XCTAssertNil(summary.primaryCurrency)
        XCTAssertNil(summary.totalAmount)
    }

    func testExcludesPaidAndClosedAndSumsPrimaryCurrency() {
        let deals = [
            makeDeal(stage: .lead, amount: 100),
            makeDeal(stage: .proposal, amount: 50),
            makeDeal(stage: .paid, amount: 999),
            makeDeal(stage: .closed, amount: 888)
        ]

        let summary = PipelineSummaryBuilder.summary(from: deals)

        XCTAssertEqual(summary.openDealCount, 2)
        XCTAssertEqual(summary.pricedDealCount, 2)
        XCTAssertEqual(summary.primaryCurrency, "USD")
        XCTAssertEqual(summary.totalAmount, 150)
        XCTAssertEqual(summary.amountByCurrency["USD"], 150)
    }

    func testGroupsAmountsByCurrencyAndKeepsPrimaryTotal() {
        let deals = [
            makeDeal(stage: .lead, amount: 100, currency: "USD"),
            makeDeal(stage: .quote, amount: 200, currency: "EUR"),
            makeDeal(stage: .proposal) // unpriced open deal
        ]

        let summary = PipelineSummaryBuilder.summary(from: deals)

        XCTAssertEqual(summary.openDealCount, 3)
        XCTAssertEqual(summary.pricedDealCount, 2)
        XCTAssertEqual(summary.primaryCurrency, "USD")
        XCTAssertEqual(summary.amountByCurrency["USD"], 100)
        XCTAssertEqual(summary.amountByCurrency["EUR"], 200)
        XCTAssertEqual(summary.totalAmount, 100)
    }
}

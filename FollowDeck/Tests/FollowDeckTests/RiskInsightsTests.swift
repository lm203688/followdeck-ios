//
//  RiskInsightsTests.swift
//  FollowDeckTests
//
//  Boundary and level tests for the portable follow-up bucket and deal risk derivation.
//

import XCTest
@testable import FollowDeck

final class RiskInsightsTests: XCTestCase {
    private let calendar = Calendar.current
    private let now = Date()

    // MARK: - Follow-up buckets

    func testBucketOverdueTodayUpcoming() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let laterToday = calendar.date(byAdding: .hour, value: 2, to: calendar.startOfDay(for: now))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        XCTAssertEqual(RiskInsights.bucket(for: FollowUp(clientID: UUID(), note: "old", dueAt: yesterday), now: now), .overdue)
        XCTAssertEqual(RiskInsights.bucket(for: FollowUp(clientID: UUID(), note: "today", dueAt: laterToday), now: now), .today)
        XCTAssertEqual(RiskInsights.bucket(for: FollowUp(clientID: UUID(), note: "soon", dueAt: tomorrow), now: now), .upcoming)
    }

    // MARK: - Deal risk levels

    func testPaidAndClosedAreNone() {
        let paid = Deal(clientID: UUID(), title: "Paid", stage: .paid, updatedAt: now)
        let closed = Deal(clientID: UUID(), title: "Closed", stage: .closed, updatedAt: now)

        XCTAssertEqual(RiskInsights.risk(for: paid, now: now).level, .none)
        XCTAssertEqual(RiskInsights.risk(for: closed, now: now).level, .none)
    }

    func testAtRiskStageIsHigh() {
        let deal = Deal(clientID: UUID(), title: "Stuck", stage: .atRisk, updatedAt: now)
        XCTAssertEqual(RiskInsights.risk(for: deal, now: now).level, .high)
    }

    func testFreshDealIsLow() {
        let deal = Deal(clientID: UUID(), title: "Fresh", stage: .proposal, updatedAt: now)
        XCTAssertEqual(RiskInsights.risk(for: deal, now: now).level, .low)
    }

    func testStalledPastThresholdIsHigh() {
        let stale = calendar.date(byAdding: .day, value: -10, to: now)!
        let deal = Deal(clientID: UUID(), title: "Stalled", stage: .proposal, updatedAt: stale)

        let risk = RiskInsights.risk(for: deal, now: now)
        XCTAssertEqual(risk.level, .high)
        XCTAssertGreaterThanOrEqual(risk.daysStale, 9)
    }

    func testDriftingDealIsMedium() {
        // Proposal threshold is 3 days; 2 days in is past the half-threshold but not stalled.
        let drifting = calendar.date(byAdding: .day, value: -2, to: now)!
        let deal = Deal(clientID: UUID(), title: "Drifting", stage: .proposal, updatedAt: drifting)

        XCTAssertEqual(RiskInsights.risk(for: deal, now: now).level, .medium)
    }
}

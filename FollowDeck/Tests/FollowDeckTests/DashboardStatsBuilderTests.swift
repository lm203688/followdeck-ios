//
//  DashboardStatsBuilderTests.swift
//  FollowDeckTests
//
//  Verify the dashboard summary counts clients, open deals (excluding paid/closed) and the
//  pending follow-up buckets.
//

import XCTest
@testable import FollowDeck

final class DashboardStatsBuilderTests: XCTestCase {

    func testEmptyStoreIsZeroed() {
        let store = InMemoryStore()
        let stats = DashboardStatsBuilder.stats(from: store)

        XCTAssertEqual(stats.clientCount, 0)
        XCTAssertEqual(stats.openDealCount, 0)
        XCTAssertEqual(stats.pendingFollowUpCount, 0)
        XCTAssertEqual(stats.overdueCount, 0)
        XCTAssertEqual(stats.todayCount, 0)
        XCTAssertEqual(stats.upcomingCount, 0)
    }

    func testCountsClientsOpenDealsAndBuckets() {
        let store = InMemoryStore()
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        let client = Client(name: "Mona")
        store.addClient(client)

        let openDeal = Deal(clientID: client.id, title: "Active", stage: .proposal)
        let closedDeal = Deal(clientID: client.id, title: "Done", stage: .paid)
        store.addDeal(openDeal)
        store.addDeal(closedDeal)

        let overdue = FollowUp(clientID: client.id, note: "Overdue", dueAt: startOfToday.addingTimeInterval(-86_400))
        let today = FollowUp(clientID: client.id, note: "Today", dueAt: startOfToday.addingTimeInterval(3_600))
        let upcoming = FollowUp(clientID: client.id, note: "Later", dueAt: startOfToday.addingTimeInterval(3 * 86_400))
        [overdue, today, upcoming].forEach { store.addFollowUp($0) }

        let stats = DashboardStatsBuilder.stats(from: store, now: now, calendar: calendar)

        XCTAssertEqual(stats.clientCount, 1)
        XCTAssertEqual(stats.openDealCount, 1)
        XCTAssertEqual(stats.pendingFollowUpCount, 3)
        XCTAssertEqual(stats.overdueCount, 1)
        XCTAssertEqual(stats.todayCount, 1)
        XCTAssertEqual(stats.upcomingCount, 1)
    }
}

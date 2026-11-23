//
//  WidgetSnapshotBuilderTests.swift
//  FollowDeckTests
//
//  Verify the widget summary buckets pending follow-ups the same way the Today board does.
//

import XCTest
@testable import FollowDeck

final class WidgetSnapshotBuilderTests: XCTestCase {

    private func makeStore(now: Date) -> InMemoryStore {
        InMemoryStore()
    }

    func testEmptyStoreSnapshotIsZeroed() {
        let store = makeStore(now: Date())
        let snapshot = WidgetSnapshotBuilder.snapshot(from: store)

        XCTAssertEqual(snapshot.overdueCount, 0)
        XCTAssertEqual(snapshot.todayCount, 0)
        XCTAssertEqual(snapshot.upcomingCount, 0)
        XCTAssertTrue(snapshot.topTitles.isEmpty)
    }

    func testSnapshotBucketsOverdueTodayAndUpcoming() {
        let store = InMemoryStore()
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        let overdue = FollowUp(clientID: UUID(), note: "Overdue call",
                                dueAt: startOfToday.addingTimeInterval(-86_400))
        let today = FollowUp(clientID: UUID(), note: "Today follow-up",
                             dueAt: startOfToday.addingTimeInterval(3_600))
        let upcoming = FollowUp(clientID: UUID(), note: "Later task",
                                dueAt: startOfToday.addingTimeInterval(3 * 86_400))
        [overdue, today, upcoming].forEach { store.addFollowUp($0) }

        let snapshot = WidgetSnapshotBuilder.snapshot(from: store, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.overdueCount, 1)
        XCTAssertEqual(snapshot.todayCount, 1)
        XCTAssertEqual(snapshot.upcomingCount, 1)
        XCTAssertEqual(snapshot.topTitles.count, 3)
    }

    func testSnapshotKeepsAtMostThreeTitles() {
        let store = InMemoryStore()
        let now = Date()
        for index in 1...5 {
            store.addFollowUp(FollowUp(clientID: UUID(), note: "Task \(index)", dueAt: now.addingTimeInterval(Double(index) * 3_600)))
        }

        let snapshot = WidgetSnapshotBuilder.snapshot(from: store, now: now)

        XCTAssertEqual(snapshot.topTitles.count, 3)
    }
}

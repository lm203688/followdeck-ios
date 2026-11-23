//
//  FollowUpSnoozeTests.swift
//  FollowDeckTests
//
//  Verify snooze bucketing: status flips to snoozed, the due date moves forward
//  by the option's day count, and all other fields are preserved.
//

import XCTest
@testable import FollowDeck

final class FollowUpSnoozeTests: XCTestCase {
    private let calendar = Calendar.current
    private let now = Date()

    private func makeFollowUp(status: FollowUpStatus = .pending) -> FollowUp {
        FollowUp(dealID: nil, clientID: UUID(), type: .proposal, note: "Call back",
                 dueAt: now, status: status, channel: .call)
    }

    func testTomorrowSnoozeMovesOneDayForward() {
        let original = makeFollowUp()
        let snoozed = FollowUpSnooze.snoozing(original, option: .tomorrow, now: now)

        XCTAssertEqual(snoozed.status, .snoozed)
        let expected = calendar.date(byAdding: .day, value: 1, to: now)!
        XCTAssertEqual(snoozed.dueAt.timeIntervalSince(expected), 0, accuracy: 1)
        XCTAssertEqual(snoozed.note, original.note)
        XCTAssertEqual(snoozed.clientID, original.clientID)
        XCTAssertEqual(snoozed.type, original.type)
        XCTAssertEqual(snoozed.channel, original.channel)
    }

    func testThreeDaysAndWeekBuckets() {
        let three = FollowUpSnooze.snoozing(makeFollowUp(), option: .threeDays, now: now)
        let week = FollowUpSnooze.snoozing(makeFollowUp(), option: .week, now: now)

        XCTAssertEqual(three.status, .snoozed)
        XCTAssertEqual(week.status, .snoozed)
        XCTAssertEqual(three.dueAt.timeIntervalSince(calendar.date(byAdding: .day, value: 3, to: now)!), 0, accuracy: 1)
        XCTAssertEqual(week.dueAt.timeIntervalSince(calendar.date(byAdding: .day, value: 7, to: now)!), 0, accuracy: 1)
    }

    func testOptionDayCountsAndLabels() {
        XCTAssertEqual(SnoozeOption.tomorrow.days, 1)
        XCTAssertEqual(SnoozeOption.threeDays.days, 3)
        XCTAssertEqual(SnoozeOption.week.days, 7)
        XCTAssertEqual(SnoozeOption.tomorrow.title, "Tomorrow")
        XCTAssertEqual(SnoozeOption.threeDays.title, "In 3 days")
        XCTAssertEqual(SnoozeOption.week.title, "In a week")
    }
}

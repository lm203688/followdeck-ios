//
//  BridgeReminderTests.swift
//  FollowDeckTests
//
//  Verify the StoreBridge wires follow-up writes to the reminder service: schedule on add,
//  reschedule on update, cancel on complete / delete, and cascade-cancel on client delete.
//  A fake reminder records calls; no UNUserNotificationCenter is touched.
//

import XCTest
@testable import FollowDeck

private final class FakeReminder: ReminderServiceProtocol {
    var scheduled: [FollowUp] = []
    var rescheduled: [FollowUp] = []
    var cancelled: [UUID] = []

    func requestAuthorization() async throws {}
    func schedule(_ followUp: FollowUp) { scheduled.append(followUp) }
    func cancel(id: UUID) { cancelled.append(id) }
    func reschedule(_ followUp: FollowUp) { rescheduled.append(followUp) }
}

final class BridgeReminderTests: XCTestCase {

    func testAddFollowUpSchedulesReminder() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeReminder()
            let bridge = StoreBridge(store: store, reminder: fake)
            let client = Client(name: "Ada")
            bridge.addClient(client)
            let followUp = FollowUp(clientID: client.id, note: "Call back",
                                     dueAt: Date().addingTimeInterval(3600))

            bridge.addFollowUp(followUp)

            XCTAssertEqual(fake.scheduled.map(\.id), [followUp.id])
            XCTAssertTrue(fake.cancelled.isEmpty)
        }
    }

    func testUpdateFollowUpReschedulesReminder() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeReminder()
            let bridge = StoreBridge(store: store, reminder: fake)
            let client = Client(name: "Bob")
            bridge.addClient(client)
            var followUp = FollowUp(clientID: client.id, note: "Send quote",
                                    dueAt: Date().addingTimeInterval(3600))
            bridge.addFollowUp(followUp)

            followUp.note = "Send revised quote"
            bridge.updateFollowUp(followUp)

            XCTAssertEqual(fake.rescheduled.map(\.id), [followUp.id])
        }
    }

    func testCompleteFollowUpCancelsReminder() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeReminder()
            let bridge = StoreBridge(store: store, reminder: fake)
            let client = Client(name: "Cara")
            bridge.addClient(client)
            let followUp = FollowUp(clientID: client.id, note: "Follow up",
                                     dueAt: Date().addingTimeInterval(3600))
            bridge.addFollowUp(followUp)

            bridge.completeFollowUp(id: followUp.id, at: Date())

            XCTAssertEqual(fake.cancelled, [followUp.id])
        }
    }

    func testDeleteFollowUpCancelsReminder() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeReminder()
            let bridge = StoreBridge(store: store, reminder: fake)
            let client = Client(name: "Dan")
            bridge.addClient(client)
            let followUp = FollowUp(clientID: client.id, note: "Chase invoice",
                                     dueAt: Date().addingTimeInterval(3600))
            bridge.addFollowUp(followUp)

            bridge.deleteFollowUp(id: followUp.id)

            XCTAssertEqual(fake.cancelled, [followUp.id])
        }
    }

    func testDeleteClientCancelsAllItsReminders() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeReminder()
            let bridge = StoreBridge(store: store, reminder: fake)
            let client = Client(name: "Eve")
            bridge.addClient(client)
            let first = FollowUp(clientID: client.id, note: "First",
                                 dueAt: Date().addingTimeInterval(3600))
            let second = FollowUp(clientID: client.id, note: "Second",
                                   dueAt: Date().addingTimeInterval(7200))
            bridge.addFollowUp(first)
            bridge.addFollowUp(second)

            bridge.deleteClient(id: client.id)

            XCTAssertEqual(Set(fake.cancelled), [first.id, second.id])
        }
    }
}

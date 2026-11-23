//
//  LastContactTests.swift
//  FollowDeckTests
//
//  Verify the bridge advances a client's last-contacted time when an interaction is logged or
//  a follow-up is completed, and that older events never roll a more recent value back.
//

import XCTest
@testable import FollowDeck

private final class NoopReminder: ReminderServiceProtocol {
    func requestAuthorization() async throws {}
    func schedule(_ followUp: FollowUp) {}
    func cancel(id: UUID) {}
    func reschedule(_ followUp: FollowUp) {}
}

final class LastContactTests: XCTestCase {

    func testLoggedInteractionUpdatesLastContactedAt() async {
        await MainActor.run {
            let store = InMemoryStore()
            let bridge = StoreBridge(store: store, reminder: NoopReminder())
            let client = Client(name: "Iris")
            bridge.addClient(client)
            let when = Date().addingTimeInterval(-1_800)

            let interaction = Interaction(clientID: client.id, channel: .call, summary: "Called", date: when)
            bridge.addInteraction(interaction)

            XCTAssertEqual(bridge.client(id: client.id)?.lastContactedAt, when)
        }
    }

    func testCompletedFollowUpUpdatesLastContactedAt() async {
        await MainActor.run {
            let store = InMemoryStore()
            let bridge = StoreBridge(store: store, reminder: NoopReminder())
            let client = Client(name: "Jude")
            bridge.addClient(client)
            let followUp = FollowUp(clientID: client.id, note: "Follow up", dueAt: Date().addingTimeInterval(3600))
            bridge.addFollowUp(followUp)
            let when = Date()

            bridge.completeFollowUp(id: followUp.id, at: when)

            XCTAssertEqual(bridge.client(id: client.id)?.lastContactedAt, when)
        }
    }

    func testOlderEventDoesNotRollBackRecentLastContactedAt() async {
        await MainActor.run {
            let store = InMemoryStore()
            let bridge = StoreBridge(store: store, reminder: NoopReminder())
            let recent = Date().addingTimeInterval(-60)
            var client = Client(name: "Kim", lastContactedAt: recent)
            bridge.addClient(client)
            let older = Date().addingTimeInterval(-7_200)

            let interaction = Interaction(clientID: client.id, channel: .email, summary: "Old", date: older)
            bridge.addInteraction(interaction)

            XCTAssertEqual(bridge.client(id: client.id)?.lastContactedAt, recent)
        }
    }
}

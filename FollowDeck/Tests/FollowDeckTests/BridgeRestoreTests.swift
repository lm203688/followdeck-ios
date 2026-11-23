//
//  BridgeRestoreTests.swift
//  FollowDeckTests
//
//  Verify the StoreBridge restore path: outgoing reminders are cancelled and the
//  Spotlight index cleared before the whole-library replace, then the restored
//  clients / deals are indexed and restored follow-ups are scheduled. Fakes stand
//  in for the reminder and Spotlight services; no system center or index is touched.
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

private final class FakeSpotlight: SpotlightIndexerProtocol {
    var indexedClients: [UUID] = []
    var indexedDeals: [UUID] = []
    var removed: [UUID] = []
    var removeAllCalled = false

    func index(client: Client) { indexedClients.append(client.id) }
    func index(deal: Deal) { indexedDeals.append(deal.id) }
    func removeRecord(id: UUID) { removed.append(id) }
    func removeAll() { removeAllCalled = true }
}

final class BridgeRestoreTests: XCTestCase {

    @MainActor
    private func makeBridge() -> (StoreBridge, InMemoryStore, FakeReminder, FakeSpotlight) {
        let store = InMemoryStore()
        let reminder = FakeReminder()
        let spotlight = FakeSpotlight()
        let bridge = StoreBridge(store: store, reminder: reminder, spotlight: spotlight)
        return (bridge, store, reminder, spotlight)
    }

    func testRestoreReplacesRecordsAndRebuildsIndexAndReminders() async {
        await MainActor.run {
            let (bridge, store, reminder, spotlight) = makeBridge()

            let oldClient = Client(name: "Old Client")
            let oldDeal = Deal(clientID: oldClient.id, title: "Old deal")
            let oldFollowUp = FollowUp(clientID: oldClient.id, note: "Old follow-up",
                                      dueAt: Date().addingTimeInterval(3600))
            bridge.addClient(oldClient)
            bridge.addDeal(oldDeal)
            bridge.addFollowUp(oldFollowUp)

            let newClient = Client(id: UUID(), name: "New Client")
            let newDeal = Deal(id: UUID(), clientID: newClient.id, title: "New deal", stage: .quote)
            let newFollowUp = FollowUp(id: UUID(), clientID: newClient.id, note: "New follow-up",
                                       dueAt: Date().addingTimeInterval(3600))
            let newInteraction = Interaction(id: UUID(), clientID: newClient.id, channel: .meeting,
                                             summary: "New meeting")
            let result = ImportResult(
                clients: [newClient],
                deals: [newDeal],
                followUps: [newFollowUp],
                interactions: [newInteraction],
                droppedDealIDs: [],
                droppedFollowUpIDs: [],
                droppedInteractionIDs: [],
                duplicateClientIDs: []
            )

            bridge.restore(result)

            XCTAssertEqual(store.clients().map(\.id), [newClient.id])
            XCTAssertEqual(store.allDeals().map(\.id), [newDeal.id])
            XCTAssertEqual(store.allFollowUps().map(\.id), [newFollowUp.id])
            XCTAssertEqual(store.allInteractions().map(\.id), [newInteraction.id])

            // Old follow-up reminder cancelled; restored follow-up scheduled.
            XCTAssertEqual(reminder.cancelled, [oldFollowUp.id])
            XCTAssertEqual(reminder.scheduled.map(\.id), [newFollowUp.id])

            // Spotlight cleared, then restored records indexed.
            XCTAssertTrue(spotlight.removeAllCalled)
            XCTAssertEqual(spotlight.indexedClients, [newClient.id])
            XCTAssertEqual(spotlight.indexedDeals, [newDeal.id])
        }
    }

    func testRestoreWithEmptySetClearsLibraryAndCancelsOldReminders() async {
        await MainActor.run {
            let (bridge, store, reminder, spotlight) = makeBridge()

            let oldClient = Client(name: "To clear")
            let oldFollowUp = FollowUp(clientID: oldClient.id, note: "Pending old",
                                       dueAt: Date().addingTimeInterval(3600))
            bridge.addClient(oldClient)
            bridge.addFollowUp(oldFollowUp)

            let empty = ImportResult(clients: [], deals: [], followUps: [], interactions: [],
                                     droppedDealIDs: [], droppedFollowUpIDs: [],
                                     droppedInteractionIDs: [], duplicateClientIDs: [])
            bridge.restore(empty)

            XCTAssertTrue(store.clients().isEmpty)
            XCTAssertTrue(store.allDeals().isEmpty)
            XCTAssertTrue(store.allFollowUps().isEmpty)
            XCTAssertTrue(store.allInteractions().isEmpty)
            XCTAssertEqual(reminder.cancelled, [oldFollowUp.id])
            XCTAssertTrue(spotlight.removeAllCalled)
            XCTAssertTrue(spotlight.indexedClients.isEmpty)
            XCTAssertTrue(spotlight.indexedDeals.isEmpty)
        }
    }
}

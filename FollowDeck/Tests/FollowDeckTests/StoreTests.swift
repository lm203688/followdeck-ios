//
//  StoreTests.swift
//  FollowDeckTests
//
//  Service-layer tests over the in-memory store. The SwiftData store shares the
//  same StoreProtocol; these cover the protocol contract (CRUD + cascade) that
//  the persistence implementation must also satisfy.
//

import XCTest
@testable import FollowDeck

final class StoreTests: XCTestCase {
    private func makeStore() -> InMemoryStore { InMemoryStore() }

    func testAddAndFetchClient() {
        let store = makeStore()
        let client = Client(name: "Ada Lovelace", email: "ada@example.com")
        store.addClient(client)

        let fetched = store.client(id: client.id)
        XCTAssertEqual(fetched?.name, "Ada Lovelace")
        XCTAssertEqual(fetched?.email, "ada@example.com")
    }

    func testCompleteFollowUpMarksDoneAndLeavesPending() {
        let store = makeStore()
        let client = Client(name: "Bob")
        store.addClient(client)
        let followUp = FollowUp(clientID: client.id, note: "Call back", dueAt: Date())
        store.addFollowUp(followUp)

        XCTAssertEqual(store.pendingFollowUps().count, 1)

        store.completeFollowUp(id: followUp.id, at: Date())

        let stored = store.allFollowUps().first
        XCTAssertEqual(stored?.status, .done)
        XCTAssertNotNil(stored?.completedAt)
        XCTAssertTrue(store.pendingFollowUps().isEmpty)
    }

    func testDeleteFollowUpRemovesIt() {
        let store = makeStore()
        let client = Client(name: "Cara")
        store.addClient(client)
        let followUp = FollowUp(clientID: client.id, note: "Send quote", dueAt: Date())
        store.addFollowUp(followUp)

        store.deleteFollowUp(id: followUp.id)

        XCTAssertTrue(store.allFollowUps().isEmpty)
    }

    func testDealsFilterByClient() {
        let store = makeStore()
        let clientA = Client(name: "Alpha")
        let clientB = Client(name: "Beta")
        store.addClient(clientA)
        store.addClient(clientB)
        store.addDeal(Deal(clientID: clientA.id, title: "Design sprint"))
        store.addDeal(Deal(clientID: clientB.id, title: "Audit"))

        XCTAssertEqual(store.deals(for: clientA.id).count, 1)
        XCTAssertEqual(store.deals(for: clientB.id).count, 1)
        XCTAssertEqual(store.allDeals().count, 2)
    }

    func testDeleteClientCascadesToFollowUpsDealsAndInteractions() {
        let store = makeStore()
        let client = Client(name: "Deleted Contact")
        store.addClient(client)
        store.addFollowUp(FollowUp(clientID: client.id, note: "Follow up", dueAt: Date()))
        store.addDeal(Deal(clientID: client.id, title: "Open deal"))
        store.addInteraction(Interaction(clientID: client.id, channel: .call, summary: "Initial call"))

        store.deleteClient(id: client.id)

        XCTAssertNil(store.client(id: client.id))
        XCTAssertTrue(store.allFollowUps().isEmpty)
        XCTAssertTrue(store.allDeals().isEmpty)
        XCTAssertTrue(store.interactions(for: client.id).isEmpty)
    }

    func testSeedPopulatesEmptyStore() {
        let store = makeStore()
        SampleData.seedIfEmpty(store: store)

        XCTAssertFalse(store.clients().isEmpty)
        XCTAssertFalse(store.allFollowUps().isEmpty)
        XCTAssertFalse(store.allDeals().isEmpty)
    }

    func testSeedDoesNotDuplicateExistingData() {
        let store = makeStore()
        store.addClient(Client(name: "Only Existing"))

        SampleData.seedIfEmpty(store: store)

        XCTAssertEqual(store.clients().count, 1)
        XCTAssertEqual(store.allFollowUps().count, 0)
        XCTAssertEqual(store.allDeals().count, 0)
    }

    func testReplaceAllReplacesExistingRecords() {
        let store = makeStore()
        store.addClient(Client(name: "Old Client"))
        store.addDeal(Deal(clientID: UUID(), title: "Old deal"))
        store.addFollowUp(FollowUp(clientID: UUID(), note: "Old follow-up", dueAt: Date()))

        let newClient = Client(id: UUID(), name: "New Client", email: "new@example.com")
        let newDeal = Deal(id: UUID(), clientID: newClient.id, title: "New deal", stage: .quote)
        let newFollowUp = FollowUp(id: UUID(), clientID: newClient.id, note: "New follow-up", dueAt: Date())
        let newInteraction = Interaction(id: UUID(), clientID: newClient.id, channel: .meeting, summary: "New meeting")

        store.replaceAll(clients: [newClient], deals: [newDeal], followUps: [newFollowUp], interactions: [newInteraction])

        XCTAssertEqual(store.clients().map { $0.name }, ["New Client"])
        XCTAssertEqual(store.allDeals().count, 1)
        XCTAssertEqual(store.allFollowUps().count, 1)
        XCTAssertEqual(store.allInteractions().count, 1)
        XCTAssertNil(store.client(id: UUID()))
    }

    func testReplaceAllWithEmptySetClearsStore() {
        let store = makeStore()
        store.addClient(Client(name: "To be cleared"))
        store.addDeal(Deal(clientID: UUID(), title: "Cleared deal"))
        store.addFollowUp(FollowUp(clientID: UUID(), note: "Cleared follow-up", dueAt: Date()))
        store.addInteraction(Interaction(clientID: UUID(), channel: .call, summary: "Cleared call"))

        store.replaceAll(clients: [], deals: [], followUps: [], interactions: [])

        XCTAssertTrue(store.clients().isEmpty)
        XCTAssertTrue(store.allDeals().isEmpty)
        XCTAssertTrue(store.allFollowUps().isEmpty)
        XCTAssertTrue(store.allInteractions().isEmpty)
    }
}

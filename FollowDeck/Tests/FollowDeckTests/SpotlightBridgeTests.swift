//
//  SpotlightBridgeTests.swift
//  FollowDeckTests
//
//  Verify the bridge keeps the Spotlight index in sync: index on add/update, remove on
//  delete, and cascade-remove a client's deals when the client is deleted.
//

import XCTest
@testable import FollowDeck

private final class FakeSpotlight: SpotlightIndexerProtocol {
    var indexedClients: [Client] = []
    var indexedDeals: [Deal] = []
    var removed: [UUID] = []

    func index(client: Client) { indexedClients.append(client) }
    func index(deal: Deal) { indexedDeals.append(deal) }
    func removeRecord(id: UUID) { removed.append(id) }
    func removeAll() { removed.removeAll() }
}

final class SpotlightBridgeTests: XCTestCase {

    func testAddClientAndDealAreIndexed() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeSpotlight()
            let bridge = StoreBridge(store: store, spotlight: fake)
            let client = Client(name: "Grace")
            bridge.addClient(client)
            let deal = Deal(clientID: client.id, title: "Retainer")
            bridge.addDeal(deal)

            XCTAssertEqual(fake.indexedClients.map(\.id), [client.id])
            XCTAssertEqual(fake.indexedDeals.map(\.id), [deal.id])
        }
    }

    func testUpdateClientAndDealReindex() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeSpotlight()
            let bridge = StoreBridge(store: store, spotlight: fake)
            var client = Client(name: "Heidi")
            bridge.addClient(client)

            client.notes = "VIP"
            bridge.updateClient(client)

            XCTAssertEqual(fake.indexedClients.count, 2)
            XCTAssertEqual(fake.indexedClients.last?.id, client.id)
        }
    }

    func testDeleteDealRemovesIndexedDeal() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeSpotlight()
            let bridge = StoreBridge(store: store, spotlight: fake)
            let client = Client(name: "Ivan")
            bridge.addClient(client)
            let deal = Deal(clientID: client.id, title: "Project")
            bridge.addDeal(deal)

            bridge.deleteDeal(id: deal.id)

            XCTAssertEqual(fake.removed, [deal.id])
        }
    }

    func testDeleteClientCascadesRemovesClientAndDeals() async {
        await MainActor.run {
            let store = InMemoryStore()
            let fake = FakeSpotlight()
            let bridge = StoreBridge(store: store, spotlight: fake)
            let client = Client(name: "Judy")
            bridge.addClient(client)
            let dealA = Deal(clientID: client.id, title: "A")
            let dealB = Deal(clientID: client.id, title: "B")
            bridge.addDeal(dealA)
            bridge.addDeal(dealB)

            bridge.deleteClient(id: client.id)

            XCTAssertEqual(Set(fake.removed), [client.id, dealA.id, dealB.id])
        }
    }
}

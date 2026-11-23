//
//  ExportBuilderTests.swift
//  FollowDeckTests
//
//  Verify the store-to-snapshot aggregation, file naming, and JSON round trip behind the
//  local export share sheet.
//

import XCTest
@testable import FollowDeck

final class ExportBuilderTests: XCTestCase {

    func testEmptyStoreProducesEmptySnapshot() {
        let store = InMemoryStore()
        let snapshot = ExportBuilder.snapshot(from: store)

        XCTAssertTrue(snapshot.clients.isEmpty)
        XCTAssertTrue(snapshot.deals.isEmpty)
        XCTAssertTrue(snapshot.followUps.isEmpty)
        XCTAssertTrue(snapshot.interactions.isEmpty)
    }

    func testSnapshotAggregatesAllRecordTypes() {
        let store = InMemoryStore()
        let client = Client(name: "Nora")
        store.addClient(client)
        let deal = Deal(clientID: client.id, title: "Retainer")
        store.addDeal(deal)
        let followUp = FollowUp(clientID: client.id, note: "Call back", dueAt: Date())
        store.addFollowUp(followUp)
        let interaction = Interaction(clientID: client.id, channel: .call, summary: "Intro call")
        store.addInteraction(interaction)

        let snapshot = ExportBuilder.snapshot(from: store)

        XCTAssertEqual(snapshot.clients.map(\.id), [client.id])
        XCTAssertEqual(snapshot.deals.map(\.id), [deal.id])
        XCTAssertEqual(snapshot.followUps.map(\.id), [followUp.id])
        XCTAssertEqual(snapshot.interactions.map(\.id), [interaction.id])
    }

    func testFileNameFollowsExportStampPattern() throws {
        let store = InMemoryStore()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let file = try ExportBuilder.makeFile(from: store, date: date)

        XCTAssertTrue(file.fileName.hasPrefix("followdeck-export-"))
        XCTAssertTrue(file.fileName.hasSuffix(".json"))
        XCTAssertFalse(file.data.isEmpty)
    }

    func testExportedJSONRoundTrips() throws {
        let store = InMemoryStore()
        let client = Client(name: "Oscar")
        store.addClient(client)
        let deal = Deal(clientID: client.id, title: "Project")
        store.addDeal(deal)

        let file = try ExportBuilder.makeFile(from: store)
        let decoded = try ExportService.snapshot(from: file.data)

        XCTAssertEqual(decoded.clients.map(\.id), [client.id])
        XCTAssertEqual(decoded.deals.map(\.id), [deal.id])
        XCTAssertEqual(decoded.exportedAt.timeIntervalSince1970,
                       ExportBuilder.snapshot(from: store).exportedAt.timeIntervalSince1970,
                       accuracy: 1.0)
    }
}

//
//  ImportParserTests.swift
//  FollowDeckTests
//
//  Verify backup decode, error classification, foreign-key consistency, orphan
//  dropping and duplicate-id de-duplication for the local restore validation.
//

import XCTest
@testable import FollowDeck

final class ImportParserTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func encode(_ snapshot: ExportSnapshot) throws -> Data {
        try ExportService.jsonData(for: snapshot)
    }

    func testValidSnapshotRoundTrips() throws {
        let client = Client(id: UUID(), name: "Nora Blake", createdAt: date, status: "active")
        let deal = Deal(id: UUID(), clientID: client.id, title: "Retainer", stage: .proposal,
                        amount: 4_800, currency: "USD", createdAt: date, updatedAt: date)
        let followUp = FollowUp(id: UUID(), dealID: deal.id, clientID: client.id, type: .proposal,
                                note: "Send proposal", dueAt: date, status: .pending, channel: .email,
                                createdAt: date)
        let interaction = Interaction(id: UUID(), clientID: client.id, dealID: deal.id,
                                      channel: .call, summary: "Discovery call", date: date)
        let data = try encode(ExportService.snapshot(
            clients: [client], deals: [deal], followUps: [followUp], interactions: [interaction]
        ))

        let result = try ImportParser.parse(data: data)
        XCTAssertEqual(result.clients.count, 1)
        XCTAssertEqual(result.deals.count, 1)
        XCTAssertEqual(result.followUps.count, 1)
        XCTAssertEqual(result.interactions.count, 1)
        XCTAssertTrue(result.droppedDealIDs.isEmpty)
        XCTAssertTrue(result.droppedFollowUpIDs.isEmpty)
        XCTAssertTrue(result.droppedInteractionIDs.isEmpty)
        XCTAssertTrue(result.duplicateClientIDs.isEmpty)
    }

    func testMalformedJSONThrowsInvalidJSON() {
        let data = Data("this is not json".utf8)
        XCTAssertThrowsError(try ImportParser.parse(data: data)) { error in
            XCTAssertEqual(error as? ImportError, .invalidJSON)
        }
    }

    func testSchemaMismatchThrowsIncompatibleSchema() {
        // Legal JSON, but it does not match the snapshot model.
        let data = Data("{\"hello\": \"world\"}".utf8)
        XCTAssertThrowsError(try ImportParser.parse(data: data)) { error in
            XCTAssertEqual(error as? ImportError, .incompatibleSchema)
        }
    }

    func testEmptyClientSnapshotThrowsEmptySnapshot() throws {
        let empty = ExportService.snapshot(clients: [], deals: [], followUps: [], interactions: [])
        let data = try encode(empty)
        XCTAssertThrowsError(try ImportParser.parse(data: data)) { error in
            XCTAssertEqual(error as? ImportError, .emptySnapshot)
        }
    }

    func testOrphanDealIsDropped() throws {
        let client = Client(id: UUID(), name: "Solo Client", createdAt: date)
        let orphanDeal = Deal(id: UUID(), clientID: UUID(), title: "Lost deal", createdAt: date, updatedAt: date)
        let data = try encode(ExportService.snapshot(
            clients: [client], deals: [orphanDeal], followUps: [], interactions: []
        ))

        let result = try ImportParser.parse(data: data)
        XCTAssertEqual(result.clients.count, 1)
        XCTAssertTrue(result.deals.isEmpty)
        XCTAssertEqual(result.droppedDealIDs, [orphanDeal.id])
    }

    func testOrphanFollowUpIsDropped() throws {
        let client = Client(id: UUID(), name: "Owned Client", createdAt: date)
        // Client reference missing.
        let orphanClientFollowUp = FollowUp(id: UUID(), clientID: UUID(), note: "No client",
                                            dueAt: date, createdAt: date)
        // Client exists, but the linked deal does not.
        let orphanDealFollowUp = FollowUp(id: UUID(), dealID: UUID(), clientID: client.id,
                                          note: "No deal", dueAt: date, createdAt: date)
        let data = try encode(ExportService.snapshot(
            clients: [client], deals: [], followUps: [orphanClientFollowUp, orphanDealFollowUp], interactions: []
        ))

        let result = try ImportParser.parse(data: data)
        XCTAssertTrue(result.followUps.isEmpty)
        XCTAssertEqual(result.droppedFollowUpIDs.sorted(),
                       [orphanClientFollowUp.id, orphanDealFollowUp.id].sorted())
    }

    func testOrphanInteractionIsDropped() throws {
        let client = Client(id: UUID(), name: "Kept Client", createdAt: date)
        let orphanInteraction = Interaction(id: UUID(), clientID: UUID(), channel: .meeting,
                                            summary: "Missing client", date: date)
        let data = try encode(ExportService.snapshot(
            clients: [client], deals: [], followUps: [], interactions: [orphanInteraction]
        ))

        let result = try ImportParser.parse(data: data)
        XCTAssertTrue(result.interactions.isEmpty)
        XCTAssertEqual(result.droppedInteractionIDs, [orphanInteraction.id])
    }

    func testDuplicateClientIDKeepsFirst() throws {
        let id = UUID()
        let first = Client(id: id, name: "First Version", createdAt: date)
        let second = Client(id: id, name: "Second Version", createdAt: date)
        let data = try encode(ExportService.snapshot(
            clients: [first, second], deals: [], followUps: [], interactions: []
        ))

        let result = try ImportParser.parse(data: data)
        XCTAssertEqual(result.clients.count, 1)
        XCTAssertEqual(result.clients[0].name, "First Version")
        XCTAssertEqual(result.duplicateClientIDs, [id])
    }
}

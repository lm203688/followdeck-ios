//
//  ExportTests.swift
//  FollowDeckTests
//
//  Round-trip tests for the local JSON export snapshot: encode, decode, field preservation.
//

import XCTest
@testable import FollowDeck

final class ExportTests: XCTestCase {

    func testSnapshotRoundTripPreservesRecords() throws {
        let client = Client(name: "Ada Lovelace", email: "ada@example.com")
        let deal = Deal(clientID: client.id, title: "Design sprint", stage: .proposal, amount: 1200)
        let followUp = FollowUp(clientID: client.id, note: "Send proposal", dueAt: Date().addingTimeInterval(3600))
        let interaction = Interaction(clientID: client.id, channel: .call, summary: "Kickoff call")

        let snapshot = ExportService.snapshot(
            clients: [client],
            deals: [deal],
            followUps: [followUp],
            interactions: [interaction]
        )

        let data = try ExportService.jsonData(for: snapshot)
        let decoded = try ExportService.snapshot(from: data)

        XCTAssertEqual(decoded.clients.count, 1)
        XCTAssertEqual(decoded.deals.count, 1)
        XCTAssertEqual(decoded.followUps.count, 1)
        XCTAssertEqual(decoded.interactions.count, 1)
        XCTAssertEqual(decoded.clients.first?.name, "Ada Lovelace")
        XCTAssertEqual(decoded.deals.first?.title, "Design sprint")
        XCTAssertEqual(decoded.followUps.first?.note, "Send proposal")
        XCTAssertEqual(decoded.interactions.first?.channel, .call)
    }

    func testJSONContainsClientName() throws {
        let client = Client(name: "Grace Hopper")
        let snapshot = ExportService.snapshot(clients: [client], deals: [], followUps: [], interactions: [])

        let data = try ExportService.jsonData(for: snapshot)
        let text = String(data: data, encoding: .utf8)

        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("Grace Hopper"))
    }

    func testEmptySnapshotRoundTrips() throws {
        let snapshot = ExportService.snapshot(clients: [], deals: [], followUps: [], interactions: [])
        let data = try ExportService.jsonData(for: snapshot)
        let decoded = try ExportService.snapshot(from: data)

        XCTAssertTrue(decoded.clients.isEmpty)
        XCTAssertTrue(decoded.deals.isEmpty)
        XCTAssertTrue(decoded.followUps.isEmpty)
        XCTAssertTrue(decoded.interactions.isEmpty)
    }
}

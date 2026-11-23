//
//  CsvBuilderTests.swift
//  FollowDeckTests
//
//  Verify CSV column layout, RFC 4180 escaping, nil/empty handling and the
//  empty-snapshot case for the local contacts / follow-ups export.
//

import XCTest
@testable import FollowDeck

final class CsvBuilderTests: XCTestCase {

    private func makeSnapshot(client: Client? = nil, followUp: FollowUp? = nil) -> ExportSnapshot {
        ExportService.snapshot(
            clients: client.map { [$0] } ?? [],
            deals: [],
            followUps: followUp.map { [$0] } ?? [],
            interactions: []
        )
    }

    func testClientHeaderAndRowColumnCount() {
        let client = Client(name: "Nora Blake", phone: "555-0100", email: "nora@example.com",
                            tags: ["design", "retainer"],
                            createdAt: Date(timeIntervalSince1970: 1_700_000_000), status: "active")
        let csv = CsvBuilder.clientsCSV(from: makeSnapshot(client: client))
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines[0], CsvBuilder.clientHeader)
        XCTAssertEqual(lines[1].split(separator: ",").count, 7)
        XCTAssertTrue(lines[1].contains("Nora Blake"))
        XCTAssertTrue(lines[1].contains("nora@example.com"))
        XCTAssertTrue(lines[1].contains("design; retainer"))
    }

    func testSpecialCharactersAreEscaped() {
        // Comma, double quote and newline must be quoted; embedded quotes doubled.
        let tricky = "Acme, Inc \"Studio\"\nSecond line"
        let client = Client(name: tricky, createdAt: Date())
        let csv = CsvBuilder.clientsCSV(from: makeSnapshot(client: client))

        XCTAssertTrue(csv.contains("\"\"Studio\"\""))
        XCTAssertTrue(csv.contains("Acme, Inc"))
        XCTAssertTrue(csv.contains("Second line"))
        // The comma-bearing field is wrapped in double quotes.
        XCTAssertTrue(csv.contains("\"Acme, Inc"))
    }

    func testNilAndEmptyFieldsEmitEmptyColumns() {
        let client = Client(name: "Edge Case", phone: nil, email: nil, lastContactedAt: nil)
        let csv = CsvBuilder.clientsCSV(from: makeSnapshot(client: client))
        let row = csv.components(separatedBy: "\n")[1]

        // Name present, then three empty optional columns before tags/status/created.
        XCTAssertTrue(row.hasPrefix("Edge Case,,,"))
    }

    func testFollowUpHeaderAndRowColumnCount() {
        let followUp = FollowUp(clientID: UUID(), type: .quote, note: "Send quote",
                                dueAt: Date(timeIntervalSince1970: 1_700_000_000), status: .pending,
                                channel: .call)
        let csv = CsvBuilder.followUpsCSV(from: makeSnapshot(followUp: followUp))
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines[0], CsvBuilder.followUpHeader)
        XCTAssertEqual(lines[1].split(separator: ",").count, 8)
        XCTAssertTrue(lines[1].contains("Send quote"))
        XCTAssertTrue(lines[1].contains("pending"))
        XCTAssertTrue(lines[1].contains("call"))
    }

    func testEmptySnapshotKeepsOnlyHeader() {
        let empty = makeSnapshot()
        XCTAssertEqual(CsvBuilder.clientsCSV(from: empty), CsvBuilder.clientHeader)
        XCTAssertEqual(CsvBuilder.followUpsCSV(from: empty), CsvBuilder.followUpHeader)
    }
}

//
//  SortersTests.swift
//  FollowDeckTests
//
//  Verify default roster ordering (name, case-insensitive) and follow-up ordering
//  (pending/snoozed first by due date; completed last by completion time).
//

import XCTest
@testable import FollowDeck

final class SortersTests: XCTestCase {

    func testClientsSortCaseInsensitivelyByName() {
        let base = Date()
        let clients = [
            Client(id: UUID(), name: "Zoe", createdAt: base),
            Client(id: UUID(), name: "alice", createdAt: base),
            Client(id: UUID(), name: "Bob", createdAt: base)
        ]

        let sorted = ClientSorter.sorted(clients)

        XCTAssertEqual(sorted.map(\.name), ["alice", "Bob", "Zoe"])
    }

    func testClientNameTiesBreakByCreationDate() {
        let base = Date()
        let older = Client(id: UUID(), name: "Mona", createdAt: base)
        let newer = Client(id: UUID(), name: "Mona", createdAt: base.addingTimeInterval(60))

        let sorted = ClientSorter.sorted([newer, older])

        XCTAssertEqual(sorted.first?.id, older.id)
    }

    func testFollowUpsPutPendingFirstByDueDateAndDoneLastByCompletion() {
        let base = Date()
        let clientID = UUID()

        let pendingLater = FollowUp(id: UUID(), clientID: clientID, note: "Pending later", dueAt: base.addingTimeInterval(86_400))
        let pendingEarlier = FollowUp(id: UUID(), clientID: clientID, note: "Pending earlier", dueAt: base.addingTimeInterval(3_600))
        let doneEarlier = FollowUp(id: UUID(), clientID: clientID, note: "Done earlier", dueAt: base, status: .done, completedAt: base.addingTimeInterval(-7_200))
        let doneLater = FollowUp(id: UUID(), clientID: clientID, note: "Done later", dueAt: base, status: .done, completedAt: base)

        let sorted = FollowUpSorter.sorted([pendingLater, doneEarlier, pendingEarlier, doneLater])

        XCTAssertEqual(sorted.map(\.note), [
            "Pending earlier",
            "Pending later",
            "Done later",
            "Done earlier"
        ])
    }
}

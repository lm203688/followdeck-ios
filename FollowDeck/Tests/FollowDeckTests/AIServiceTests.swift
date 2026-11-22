//
//  AIServiceTests.swift
//  FollowDeckTests
//
//  Rule-engine tests for the local next-step suggestion: stage cadence, dwell-time escalation
//  and settled-stage handling. No network or model call is involved.
//

import XCTest
@testable import FollowDeck

final class AIServiceTests: XCTestCase {
    private let ai = AIService()
    private let calendar = Calendar.current

    func testStageActionAndCadence() async throws {
        let deal = Deal(clientID: UUID(), title: "Proposal", stage: .proposal, updatedAt: Date())

        let suggestion = try await ai.suggestNextStep(for: deal, history: [])

        XCTAssertFalse(suggestion.action.isEmpty)
        XCTAssertEqual(suggestion.generatedBy, "native")
        // Proposal cadence is 3 days; allow a small clock skew around the window.
        let lower = calendar.date(byAdding: .day, value: 2, to: Date())!
        let upper = calendar.date(byAdding: .day, value: 4, to: Date())!
        XCTAssertGreaterThan(suggestion.suggestedDueAt, lower)
        XCTAssertLessThan(suggestion.suggestedDueAt, upper)
    }

    func testStalledDealMovesDueDateEarlier() async throws {
        let staleDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        let deal = Deal(clientID: UUID(), title: "Quote", stage: .quote, updatedAt: staleDate)

        let suggestion = try await ai.suggestNextStep(for: deal, history: [])

        let upper = calendar.date(byAdding: .day, value: 2, to: Date())!
        XCTAssertLessThan(suggestion.suggestedDueAt, upper)
        XCTAssertTrue(suggestion.rationale.contains("Unchanged"))
    }

    func testPaidDealHasNoActiveStep() async throws {
        let deal = Deal(clientID: UUID(), title: "Paid", stage: .paid, updatedAt: Date())

        let suggestion = try await ai.suggestNextStep(for: deal, history: [])

        XCTAssertLessThan(abs(suggestion.suggestedDueAt.timeIntervalSinceNow), 60)
    }

    func testRationaleMentionsLastContactChannel() async throws {
        let clientID = UUID()
        let deal = Deal(clientID: clientID, title: "Delivering", stage: .delivering, updatedAt: Date())
        let interaction = Interaction(clientID: clientID, channel: .call, summary: "Kickoff")

        let suggestion = try await ai.suggestNextStep(for: deal, history: [interaction])

        XCTAssertTrue(suggestion.rationale.lowercased().contains("call"))
    }
}

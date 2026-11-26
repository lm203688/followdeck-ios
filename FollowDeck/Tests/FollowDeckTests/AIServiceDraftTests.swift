//
//  AIServiceDraftTests.swift
//  FollowDeckTests
//
//  Draft-layer fallback tests: the injected on-device model result wins when it serves,
//  and every other case falls back to the local rule template. No model or network call
//  is involved; the model generator is a stub.
//

import XCTest
@testable import FollowDeck

private final class StubModelGenerator: DraftGeneratorProtocol {
    var result: DraftResult?

    func draft(clientName: String, context: String) async -> DraftResult? {
        result
    }
}

final class AIServiceDraftTests: XCTestCase {
    private let client = Client(name: "Maya Chen", email: "maya@example.com")

    func testL2DraftIsUsedWhenModelServes() async throws {
        let stub = StubModelGenerator()
        stub.result = DraftResult(text: "Hi Maya, checking in on the proposal.", generatedBy: "on-device-model")

        let ai = AIService(modelGenerator: stub)
        let draft = try await ai.draftReengagementMessage(for: client, context: "the proposal")

        XCTAssertEqual(draft, "Hi Maya, checking in on the proposal.")
    }

    func testFallsBackToRuleWhenModelReturnsNil() async throws {
        let stub = StubModelGenerator()
        stub.result = nil

        let ai = AIService(modelGenerator: stub)
        let draft = try await ai.draftReengagementMessage(for: client, context: "the proposal")

        XCTAssertTrue(draft.contains("Maya Chen"))
        XCTAssertTrue(draft.contains("the proposal"))
    }

    func testRuleDraftAlwaysIncludesNameAndContext() async throws {
        let ai = AIService()
        let draft = try await ai.draftReengagementMessage(for: client, context: "the quote")

        XCTAssertTrue(draft.contains("Maya Chen"))
        XCTAssertTrue(draft.contains("the quote"))
    }
}

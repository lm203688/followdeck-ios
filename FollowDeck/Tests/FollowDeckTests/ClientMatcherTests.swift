//
//  ClientMatcherTests.swift
//  FollowDeckTests
//
//  Verify roster search matches across name, email, phone and tags, is
//  case-insensitive, and treats an empty / whitespace query as match-all.
//

import XCTest
@testable import FollowDeck

final class ClientMatcherTests: XCTestCase {

    private func makeClient() -> Client {
        Client(
            name: "Nora Blake",
            phone: "555-0100",
            email: "nora@example.com",
            tags: ["design", "retainer"]
        )
    }

    func testMatchesNameCaseInsensitively() {
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "nora"))
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "BLAKE"))
    }

    func testMatchesEmail() {
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "nora@example.com"))
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "EXAMPLE.com"))
    }

    func testMatchesPhone() {
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "555-0100"))
    }

    func testMatchesTag() {
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "retainer"))
        XCTAssertTrue(ClientMatcher.matches(makeClient(), query: "DESIGN"))
    }

    func testNoMatchReturnsFalse() {
        XCTAssertFalse(ClientMatcher.matches(makeClient(), query: "zzz-not-here"))
    }

    func testEmptyQueryMatchesAll() {
        let clients = [makeClient(), Client(name: "Other")]
        XCTAssertEqual(ClientMatcher.filter(clients, query: "").count, 2)
    }

    func testWhitespaceQueryMatchesAll() {
        let clients = [makeClient(), Client(name: "Other")]
        XCTAssertEqual(ClientMatcher.filter(clients, query: "   ").count, 2)
    }

    func testFilterKeepsOrder() {
        let a = Client(name: "Alpha")
        let b = Client(name: "Beta")
        let filtered = ClientMatcher.filter([a, b], query: "alpha")
        XCTAssertEqual(filtered.map(\.id), [a.id])
    }
}

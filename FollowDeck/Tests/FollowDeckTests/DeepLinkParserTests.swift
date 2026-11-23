//
//  DeepLinkParserTests.swift
//  FollowDeckTests
//
//  Verify widget / notification deep links resolve to the correct tab, with a safe Today
//  fallback for unknown hosts or foreign schemes.
//

import XCTest
@testable import FollowDeck

final class DeepLinkParserTests: XCTestCase {

    func testKnownHostsMapToTabs() {
        XCTAssertEqual(DeepLinkParser.target(for: URL(string: "followdeck://pipeline")!), .pipeline)
        XCTAssertEqual(DeepLinkParser.target(for: URL(string: "followdeck://clients")!), .clients)
        XCTAssertEqual(DeepLinkParser.target(for: URL(string: "followdeck://followups")!), .followUps)
    }

    func testTodayIsTheDefaultHost() {
        XCTAssertEqual(DeepLinkParser.target(for: URL(string: "followdeck://today")!), .today)
        XCTAssertEqual(DeepLinkParser.target(for: URL(string: "followdeck://unknown")!), .today)
    }

    func testForeignSchemeFallsBackToToday() {
        XCTAssertEqual(DeepLinkParser.target(for: URL(string: "https://example.com/pipeline")!), .today)
    }
}

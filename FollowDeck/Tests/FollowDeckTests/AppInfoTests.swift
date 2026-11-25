//
//  AppInfoTests.swift
//  FollowDeckTests
//
//  Verify version presentation and the local-only feedback mailto URL builder.
//

import XCTest
@testable import FollowDeck

final class AppInfoTests: XCTestCase {

    func testVersionDisplayIncludesBuildWhenPresent() {
        let info = AppInfo(version: "0.1.0", build: "1")
        XCTAssertEqual(info.versionDisplay, "Version 0.1.0 (1)")
    }

    func testVersionDisplayOmitsEmptyBuild() {
        let info = AppInfo(version: "0.1.0", build: "")
        XCTAssertEqual(info.versionDisplay, "Version 0.1.0")
    }

    func testFeedbackMailURLTargetsRecipientWithSubjectAndBody() throws {
        let url = try XCTUnwrap(
            FeedbackMail.composeURL(
                to: "463102527@qq.com",
                subject: "FollowDeck feedback",
                body: "Device: iOS 18\nApp: Version 0.1.0 (1)"
            )
        )
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertEqual(url.path, "463102527@qq.com")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let subject = components.queryItems?.first(where: { $0.name == "subject" })?.value
        let body = components.queryItems?.first(where: { $0.name == "body" })?.value
        XCTAssertEqual(subject, "FollowDeck feedback")
        XCTAssertEqual(body, "Device: iOS 18\nApp: Version 0.1.0 (1)")
    }
}

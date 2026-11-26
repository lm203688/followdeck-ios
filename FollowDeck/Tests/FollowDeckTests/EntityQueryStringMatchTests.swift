//
//  EntityQueryStringMatchTests.swift
//  FollowDeckTests
//
//  Verify the offline matching predicates behind the EntityStringQuery
//  conformance. These pure filters back Siri / Shortcuts string search; they
//  do not touch the store or any model framework.
//

import XCTest
@testable import FollowDeck

final class EntityQueryStringMatchTests: XCTestCase {

    private func makeClient(name: String, email: String? = nil, phone: String? = nil, tags: [String] = []) -> Client {
        Client(name: name, phone: phone, email: email, tags: tags)
    }

    func testClientMatchesNameCaseInsensitively() {
        let client = makeClient(name: "Acme Corporation", email: "hi@acme.example")
        XCTAssertTrue(ClientEntityQuery.matches(client: client, term: "acme"))
        XCTAssertTrue(ClientEntityQuery.matches(client: client, term: "CORPORATION"))
        XCTAssertFalse(ClientEntityQuery.matches(client: client, term: "Globex"))
    }

    func testClientMatchesEmailPhoneAndTags() {
        let client = makeClient(name: "Acme", email: "team@acme.example", phone: "+1 555 0100", tags: ["manufacturing"])
        XCTAssertTrue(ClientEntityQuery.matches(client: client, term: "team@acme"))
        XCTAssertTrue(ClientEntityQuery.matches(client: client, term: "555 0100"))
        XCTAssertTrue(ClientEntityQuery.matches(client: client, term: "manufacturing"))
    }

    func testFollowUpMatchesNote() {
        let followUp = FollowUp(clientID: UUID(), note: "Send the revised proposal", dueAt: Date())
        XCTAssertTrue(FollowUpEntityQuery.matches(followUp: followUp, term: "proposal"))
        XCTAssertTrue(FollowUpEntityQuery.matches(followUp: followUp, term: "REVISED"))
        XCTAssertFalse(FollowUpEntityQuery.matches(followUp: followUp, term: "invoice"))
    }

    func testDealMatchesTitleAndNextAction() {
        let deal = Deal(clientID: UUID(), title: "Website redesign", stage: .proposal, nextAction: "Follow up on the quote")
        XCTAssertTrue(DealEntityQuery.matches(deal: deal, term: "redesign"))
        XCTAssertTrue(DealEntityQuery.matches(deal: deal, term: "quote"))
        XCTAssertFalse(DealEntityQuery.matches(deal: deal, term: "onboarding"))
    }
}

//
//  FormValidatorsTests.swift
//  FollowDeckTests
//
//  Verify pure input validation for the client and deal forms: optional-field
//  emptiness, email/phone shape, amount parsing and tag normalization.
//

import XCTest
@testable import FollowDeck

final class FormValidatorsTests: XCTestCase {

    // MARK: - Email

    func testEmailIsOptionalAndAcceptsValidAddresses() {
        XCTAssertTrue(FormValidators.isValidEmail(nil))
        XCTAssertTrue(FormValidators.isValidEmail(""))
        XCTAssertTrue(FormValidators.isValidEmail("   "))
        XCTAssertTrue(FormValidators.isValidEmail("nora@studio.co"))
        XCTAssertTrue(FormValidators.isValidEmail("a.b@sub.domain.com"))
    }

    func testEmailRejectsMalformedAddresses() {
        XCTAssertFalse(FormValidators.isValidEmail("nora@"))
        XCTAssertFalse(FormValidators.isValidEmail("@studio.co"))
        XCTAssertFalse(FormValidators.isValidEmail("nora@studio"))
        XCTAssertFalse(FormValidators.isValidEmail("nora studio@co.com"))
        XCTAssertFalse(FormValidators.isValidEmail("nora@studio.c"))
        XCTAssertFalse(FormValidators.isValidEmail("nora@studio..com"))
    }

    // MARK: - Phone

    func testPhoneIsOptionalAndAcceptsFormattedNumbers() {
        XCTAssertTrue(FormValidators.isValidPhone(nil))
        XCTAssertTrue(FormValidators.isValidPhone(""))
        XCTAssertTrue(FormValidators.isValidPhone("+1 (555) 010-2233"))
        XCTAssertTrue(FormValidators.isValidPhone("5550102233"))
    }

    func testPhoneRejectsLettersAndShortNumbers() {
        XCTAssertFalse(FormValidators.isValidPhone("abc-phone"))
        XCTAssertFalse(FormValidators.isValidPhone("123"))
    }

    // MARK: - Amount

    func testAmountParsesNumericTextAndDropsSeparators() {
        XCTAssertNil(FormValidators.parsedAmount(nil))
        XCTAssertNil(FormValidators.parsedAmount(""))
        XCTAssertEqual(FormValidators.parsedAmount("1,200.50"), Decimal(string: "1200.50"))
        XCTAssertEqual(FormValidators.parsedAmount("  480 "), Decimal(string: "480"))
    }

    func testAmountRejectsNonNumericText() {
        XCTAssertNil(FormValidators.parsedAmount("abc"))
        XCTAssertNil(FormValidators.parsedAmount("12a3"))
        XCTAssertTrue(FormValidators.isValidAmount(""))
        XCTAssertTrue(FormValidators.isValidAmount("100"))
        XCTAssertFalse(FormValidators.isValidAmount("abc"))
    }

    // MARK: - Tags

    func testTagsTrimDropEmptiesAndDeDuplicateInOrder() {
        let tags = FormValidators.normalizedTags(" Alpha, beta, Alpha, ,gamma ")
        XCTAssertEqual(tags, ["Alpha", "beta", "gamma"])
    }
}

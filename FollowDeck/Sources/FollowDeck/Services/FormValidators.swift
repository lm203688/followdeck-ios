//
//  FormValidators.swift
//  FollowDeck
//
//  Pure, testable input validation for the create/edit forms. These helpers
//  only normalize and check strings; they hold no store, UI or network state.
//  Optional fields treat an empty value as valid; a filled-in value must meet
//  the format rule before the form allows saving.
//

import Foundation

enum FormValidators {

    /// Trimmed whitespace around an optional string; nil when empty.
    static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Email format check. Empty / nil is valid because email is optional.
    static func isValidEmail(_ email: String?) -> Bool {
        guard let email = trimmedOptional(email) else { return true }

        // Exactly one "@", with a non-empty local and domain part.
        let atParts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard atParts.count == 2 else { return false }
        let local = String(atParts[0])
        let domain = String(atParts[1])

        guard !local.isEmpty, !domain.isEmpty else { return false }
        guard !local.contains(" "), !domain.contains(" ") else { return false }

        // Domain needs a dot, labels that do not start/end with a dot, and a
        // TLD of at least two letters.
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        guard labels.allSatisfy({ !$0.isEmpty }) else { return false }
        let tld = labels.last!
        guard tld.count >= 2, tld.allSatisfy({ $0.isLetter }) else { return false }

        // Local part may not start or end with a dot.
        guard !local.hasPrefix("."), !local.hasSuffix(".") else { return false }
        return true
    }

    /// Phone format check. Empty / nil is valid because phone is optional.
    /// Allows digits, leading "+", spaces, dashes and parentheses; 5–20 chars.
    static func isValidPhone(_ phone: String?) -> Bool {
        guard let phone = trimmedOptional(phone) else { return true }
        let allowed: Set<Character> = Set("0123456789+ ()-")
        guard phone.allSatisfy({ allowed.contains($0) }) else { return false }
        let digits = phone.filter(\.isNumber)
        guard digits.count >= 5, digits.count <= 15 else { return false }
        return true
    }

    /// Parse an optional deal amount. Empty text -> nil; unparseable -> nil.
    /// Removes thousands separators and whitespace before parsing. A strict
    /// character whitelist is applied first because `Decimal(string:)` parses a
    /// leading numeric prefix (e.g. "12a3" -> 12) instead of failing outright.
    static func parsedAmount(_ text: String?) -> Decimal? {
        guard let text else { return nil }
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        let allowed: Set<Character> = Set("0123456789.-")
        guard cleaned.allSatisfy({ allowed.contains($0) }) else { return nil }
        guard cleaned.filter({ $0 == "." }).count <= 1 else { return nil }
        return Decimal(string: cleaned)
    }

    /// True when the amount text is either empty (optional) or parseable.
    static func isValidAmount(_ text: String?) -> Bool {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return true
        }
        return parsedAmount(text) != nil
    }

    /// Normalize comma-separated tag text: trim, drop empties, de-duplicate
    /// while preserving first-seen order.
    static func normalizedTags(_ text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for part in text.split(separator: ",") {
            let tag = part.trimmingCharacters(in: .whitespaces)
            guard !tag.isEmpty, !seen.contains(tag) else { continue }
            seen.insert(tag)
            result.append(tag)
        }
        return result
    }
}

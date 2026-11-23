//
//  Display.swift
//  FollowDeck
//
//  Shared read-only formatting helpers for screens. No business logic here;
//  maps model raw values to human-readable English labels and short dates.
//

import Foundation

extension DealStage {
    var displayName: String {
        switch self {
        case .lead:       return "Lead"
        case .proposal:   return "Proposal"
        case .quote:      return "Quote"
        case .contract:   return "Contract"
        case .delivering: return "Delivering"
        case .invoiced:   return "Invoiced"
        case .paid:       return "Paid"
        case .atRisk:     return "At Risk"
        case .closed:     return "Closed"
        }
    }
}

extension Channel {
    var displayName: String {
        switch self {
        case .email:   return "Email"
        case .call:    return "Call"
        case .message: return "Message"
        case .meeting: return "Meeting"
        case .other:   return "Other"
        }
    }
}

extension FollowUpStatus {
    var displayName: String {
        switch self {
        case .pending:  return "Pending"
        case .done:     return "Done"
        case .snoozed:  return "Snoozed"
        }
    }
}

enum DisplayFormat {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func date(_ date: Date) -> String { shortDate.string(from: date) }
    static func dateTime(_ date: Date) -> String { shortDateTime.string(from: date) }

    static func amount(_ value: Decimal?, currency: String?) -> String? {
        guard let value else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: value as NSNumber)
    }
}

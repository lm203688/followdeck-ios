//
//  Models.swift
//  FollowDeck
//
//  Data model draft — see 05-首发应用立项书-草案-v0.1.md §7.
//  Persistence layer (SwiftData / Core Data) is wired up in the Xcode project on macOS.
//

import Foundation

/// Stage of a deal / engagement.
enum DealStage: String, Codable, CaseIterable, Identifiable {
    case lead
    case proposal
    case quote
    case contract
    case delivering
    case invoiced
    case paid
    case atRisk
    case closed

    var id: String { rawValue }

    /// Default follow-up offset in days for the stage (polite nudge cadence).
    var defaultFollowUpOffsetDays: Int {
        switch self {
        case .lead:        return 3
        case .proposal:    return 3
        case .quote:       return 7
        case .contract:    return 5
        case .delivering:  return 7
        case .invoiced:    return 3
        case .paid:        return 0
        case .atRisk:      return 1
        case .closed:      return 0
        }
    }
}

/// Type of a follow-up commitment.
enum FollowUpType: String, Codable, CaseIterable {
    case followUp
    case proposal
    case quote
    case contract
    case invoice
    case payment
}

/// Status of a follow-up.
enum FollowUpStatus: String, Codable, CaseIterable {
    case pending
    case done
    case snoozed
}

/// Communication channel for an interaction.
enum Channel: String, Codable, CaseIterable {
    case email
    case call
    case message
    case meeting
    case other
}

struct Client: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var phone: String?
    var email: String?
    var tags: [String]
    var notes: String
    var avatarAssetName: String?
    var createdAt: Date
    var lastContactedAt: Date?
    var status: String

    init(id: UUID = UUID(),
         name: String,
         phone: String? = nil,
         email: String? = nil,
         tags: [String] = [],
         notes: String = "",
         avatarAssetName: String? = nil,
         createdAt: Date = Date(),
         lastContactedAt: Date? = nil,
         status: String = "active") {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.tags = tags
        self.notes = notes
        self.avatarAssetName = avatarAssetName
        self.createdAt = createdAt
        self.lastContactedAt = lastContactedAt
        self.status = status
    }
}

struct Deal: Identifiable, Codable, Equatable {
    var id: UUID
    var clientID: UUID
    var title: String
    var stage: DealStage
    var amount: Decimal?
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    var nextAction: String?
    var nextDueAt: Date?
    var ownerNote: String

    init(id: UUID = UUID(),
         clientID: UUID,
         title: String,
         stage: DealStage = .lead,
         amount: Decimal? = nil,
         currency: String = "USD",
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         nextAction: String? = nil,
         nextDueAt: Date? = nil,
         ownerNote: String = "") {
        self.id = id
        self.clientID = clientID
        self.title = title
        self.stage = stage
        self.amount = amount
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.nextAction = nextAction
        self.nextDueAt = nextDueAt
        self.ownerNote = ownerNote
    }
}

struct FollowUp: Identifiable, Codable, Equatable {
    var id: UUID
    var dealID: UUID?
    var clientID: UUID
    var type: FollowUpType
    var note: String
    var dueAt: Date
    var status: FollowUpStatus
    var channel: Channel
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(),
         dealID: UUID? = nil,
         clientID: UUID,
         type: FollowUpType = .followUp,
         note: String,
         dueAt: Date,
         status: FollowUpStatus = .pending,
         channel: Channel = .other,
         createdAt: Date = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.dealID = dealID
        self.clientID = clientID
        self.type = type
        self.note = note
        self.dueAt = dueAt
        self.status = status
        self.channel = channel
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

struct Interaction: Identifiable, Codable, Equatable {
    var id: UUID
    var clientID: UUID
    var dealID: UUID?
    var channel: Channel
    var summary: String
    var date: Date
    var durationMinutes: Int?

    init(id: UUID = UUID(),
         clientID: UUID,
         dealID: UUID? = nil,
         channel: Channel,
         summary: String,
         date: Date = Date(),
         durationMinutes: Int? = nil) {
        self.id = id
        self.clientID = clientID
        self.dealID = dealID
        self.channel = channel
        self.summary = summary
        self.date = date
        self.durationMinutes = durationMinutes
    }
}

/// Stage rule: default action cadence and escalation steps.
struct StageRule: Codable, Equatable {
    var stage: DealStage
    var suggestedAction: String
    var defaultOffsetDays: Int
    var escalationSteps: [String]
}

/// In-app feedback entry (desensitized before leaving the device).
struct FeedbackEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var category: String
    var text: String
    var screenshotAssetName: String?
    var appVersion: String
    var deviceModel: String
    var createdAt: Date

    init(id: UUID = UUID(),
         category: String,
         text: String,
         screenshotAssetName: String? = nil,
         appVersion: String,
         deviceModel: String,
         createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.text = text
        self.screenshotAssetName = screenshotAssetName
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.createdAt = createdAt
    }
}

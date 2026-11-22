//
//  AppIntents.swift
//  FollowDeck
//
//  System / Siri integration manifest. Full conformance and intent registration are
//  completed in the Xcode project on macOS. See docs/INTENTS.md for the full list.
//
//  NOTE: AppIntent parameters use String UUIDs here as a compile-safe placeholder.
//  In M1 these become AppEntity models backed by an EntityQuery so Siri can resolve
//  real clients/deals by name rather than by identifier.
//

import AppIntents
import Foundation

/// Record an interaction with a client.
struct LogInteractionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a client interaction"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Client")
    var clientID: String

    @Parameter(title: "Summary")
    var summary: String

    func perform() async throws -> some IntentResult {
        // TODO(macOS): append Interaction to the store, update lastContactedAt.
        return .result()
    }
}

/// Add a follow-up commitment tied to a client or deal.
struct AddFollowUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a follow-up"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Client")
    var clientID: String

    @Parameter(title: "Note")
    var note: String

    @Parameter(title: "Due date")
    var dueAt: Date

    func perform() async throws -> some IntentResult {
        // TODO(macOS): create FollowUp, schedule reminder via ReminderService.
        return .result()
    }
}

/// List upcoming follow-ups (read-only).
struct ListUpNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Show what is next"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // TODO(macOS): return pending follow-ups as a dialog / result.
        return .result(dialog: "Up next are loaded in FollowDeck.")
    }
}

/// Mark a follow-up done and schedule the next one if needed.
struct CompleteFollowUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete a follow-up"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Follow-up")
    var followUpID: String

    func perform() async throws -> some IntentResult {
        // TODO(macOS): complete in store, reschedule next stage action.
        return .result()
    }
}

/// Look up a client / deal status.
struct ClientStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check client status"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Client")
    var clientID: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // TODO(macOS): read current stage and next action.
        return .result(dialog: "Client status is loaded in FollowDeck.")
    }
}

/// Ask the AI service for the next step (read-only suggestion).
struct SuggestNextStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Suggest next step"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Deal")
    var dealID: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // TODO(macOS): call AIService.suggestNextStep, return editable suggestion.
        return .result(dialog: "A next-step suggestion is ready in FollowDeck.")
    }
}

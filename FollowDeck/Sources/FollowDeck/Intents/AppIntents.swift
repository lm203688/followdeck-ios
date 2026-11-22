//
//  AppIntents.swift
//  FollowDeck
//
//  System / Siri integration. Intents read and write through the shared SwiftData
//  store. String UUIDs are a placeholder until AppEntity + EntityQuery resolution
//  lands in a later iteration. See docs/INTENTS.md for the full intent list.
//

import AppIntents
import Foundation

enum FollowDeckIntentError: Error, LocalizedError {
    case invalidID
    case missingEntity

    var errorDescription: String? {
        switch self {
        case .invalidID:   return "The provided identifier is not valid."
        case .missingEntity: return "No matching record was found."
        }
    }
}

/// Record an interaction with a client.
struct LogInteractionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a client interaction"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Client")
    var clientID: String

    @Parameter(title: "Summary")
    var summary: String

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: clientID) else { throw FollowDeckIntentError.invalidID }
        try await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            guard var client = store.client(id: id) else { throw FollowDeckIntentError.missingEntity }
            let interaction = Interaction(clientID: id, channel: .other, summary: summary)
            store.addInteraction(interaction)
            client.lastContactedAt = Date()
            store.updateClient(client)
        }
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
        guard let id = UUID(uuidString: clientID) else { throw FollowDeckIntentError.invalidID }
        try await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            guard store.client(id: id) != nil else { throw FollowDeckIntentError.missingEntity }
            let followUp = FollowUp(clientID: id, note: note, dueAt: dueAt)
            store.addFollowUp(followUp)
            ReminderService().schedule(followUp)
        }
        return .result()
    }
}

/// List upcoming follow-ups (read-only).
struct ListUpNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Show what is next"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pending = await MainActor.run {
            PersistenceController.shared.makeStore().pendingFollowUps()
        }
        if pending.isEmpty {
            return .result(dialog: "You have no follow-ups due right now.")
        }
        let top = pending.prefix(5).map { item in
            let client = PersistenceController.shared.makeStore().client(id: item.clientID)?.name ?? "a client"
            return "\(client): \(item.note)"
        }
        return .result(dialog: Dialog("Up next: \(top.joined(separator: ". "))."))
    }
}

/// Mark a follow-up done and schedule the next one if needed.
struct CompleteFollowUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete a follow-up"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Follow-up")
    var followUpID: String

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: followUpID) else { throw FollowDeckIntentError.invalidID }
        try await MainActor.run {
            PersistenceController.shared.makeStore().completeFollowUp(id: id, at: Date())
        }
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
        guard let id = UUID(uuidString: clientID) else { throw FollowDeckIntentError.invalidID }
        let dialog = try await MainActor.run { () -> Dialog in
            let store = PersistenceController.shared.makeStore()
            guard let client = store.client(id: id) else { throw FollowDeckIntentError.missingEntity }
            let deals = store.deals(for: id)
            if deals.isEmpty {
                return Dialog("\(client.name) has no active deal yet.")
            }
            let summary = deals.map { "\($0.title), stage \($0.stage.displayName)" }
            return Dialog("\(client.name): \(summary.joined(separator: "; ")).")
        }
        return .result(dialog: dialog)
    }
}

/// Ask the AI service for the next step (read-only suggestion).
struct SuggestNextStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Suggest next step"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Deal")
    var dealID: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = UUID(uuidString: dealID) else { throw FollowDeckIntentError.invalidID }
        let suggestion = try await MainActor.run { () -> NextStepSuggestion in
            let store = PersistenceController.shared.makeStore()
            guard let deal = store.allDeals().first(where: { $0.id == id }) else { throw FollowDeckIntentError.missingEntity }
            let history = store.interactions(for: deal.clientID)
            return try AIService().suggestNextStep(for: deal, history: history)
        }
        return .result(dialog: Dialog("\(suggestion.action) Suggested for \(DisplayFormat.date(suggestion.suggestedDueAt))."))
    }
}

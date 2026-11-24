//
//  AppIntents.swift
//  FollowDeck
//
//  System / Siri integration. Intents read and write through the shared SwiftData
//  store; entities resolve through the AppEntity + EntityQuery pickers in Entities.swift.
//  See docs/INTENTS.md for the full intent list.
//

import AppIntents
import Foundation

enum FollowDeckIntentError: Error, LocalizedError {
    case invalidID
    case missingEntity

    var errorDescription: String? {
        switch self {
        case .invalidID:     return "The provided identifier is not valid."
        case .missingEntity: return "No matching record was found."
        }
    }
}

/// Record an interaction with a client.
struct LogInteractionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a client interaction"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Client")
    var client: ClientEntity

    @Parameter(title: "Summary")
    var summary: String

    func perform() async throws -> some IntentResult {
        let id = client.id
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
    var client: ClientEntity

    @Parameter(title: "Note")
    var note: String

    @Parameter(title: "Due date")
    var dueAt: Date

    func perform() async throws -> some IntentResult {
        let id = client.id
        try await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            guard store.client(id: id) != nil else { throw FollowDeckIntentError.missingEntity }
            let followUp = FollowUp(clientID: id, note: note, dueAt: dueAt)
            store.addFollowUp(followUp)
            ReminderService.shared.schedule(followUp)
        }
        return .result()
    }
}

/// List upcoming follow-ups (read-only).
struct ListUpNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Show what is next"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { () -> String in
            let store = PersistenceController.shared.makeStore()
            let pending = store.pendingFollowUps()
            if pending.isEmpty {
                return "You have no follow-ups due right now."
            }
            let top = pending.prefix(5).map { item -> String in
                let client = store.client(id: item.clientID)?.name ?? "a client"
                return "\(client): \(item.note)"
            }
            return "Up next: \(top.joined(separator: ". "))."
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
    }
}

/// Mark a follow-up done and schedule the next one if needed.
struct CompleteFollowUpIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete a follow-up"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Follow-up")
    var followUp: FollowUpEntity

    func perform() async throws -> some IntentResult {
        let id = followUp.id
        await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            store.completeFollowUp(id: id, at: Date())
            ReminderService.shared.cancel(id: id)
        }
        return .result()
    }
}

/// Look up a client / deal status.
struct ClientStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check client status"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Client")
    var client: ClientEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = client.id
        let text = try await MainActor.run { () -> String in
            let store = PersistenceController.shared.makeStore()
            guard let client = store.client(id: id) else { throw FollowDeckIntentError.missingEntity }
            let deals = store.deals(for: id)
            if deals.isEmpty {
                return "\(client.name) has no active deal yet."
            }
            let summary = deals.map { "\($0.title), stage \($0.stage.displayName)" }
            return "\(client.name): \(summary.joined(separator: "; "))."
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
    }
}

/// Ask the AI service for the next step (read-only suggestion).
struct SuggestNextStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Suggest next step"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Deal")
    var deal: DealEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = deal.id
        let (deal, history) = try await MainActor.run { () -> (Deal, [Interaction]) in
            let store = PersistenceController.shared.makeStore()
            guard let deal = store.allDeals().first(where: { $0.id == id }) else { throw FollowDeckIntentError.missingEntity }
            return (deal, store.interactions(for: deal.clientID))
        }
        let suggestion = try await AIService().suggestNextStep(for: deal, history: history)
        let message = "\(suggestion.action) Suggested for \(DisplayFormat.date(suggestion.suggestedDueAt))."
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: message)))
    }
}

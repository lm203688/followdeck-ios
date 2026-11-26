//
//  AIService.swift
//  FollowDeck
//
//  AI capability tiers:
//   1. Native first: on-device / system frameworks for summaries, reminder suggestions, intent parsing.
//   2. API key fallback: third-party or in-house model for generation the native stack cannot cover.
//
//  SECURITY RED LINE: API keys are never hard-coded in the client, never committed to this repo,
//  and never written into backup documents. Fallback calls go through a secure backend or a
//  compliant hosted service; keys live in the keychain / password manager only.
//

import Foundation

struct NextStepSuggestion: Equatable {
    let action: String
    let suggestedDueAt: Date
    let rationale: String
    let generatedBy: String // "native" | "api-fallback"
}

protocol AIServiceProtocol: AnyObject {
    /// Suggest the next action and timing for a deal based on stage, dwell time and history.
    func suggestNextStep(for deal: Deal, history: [Interaction]) async throws -> NextStepSuggestion

    /// Draft a short, editable re-engagement message. User reviews and edits before sending.
    func draftReengagementMessage(for client: Client, context: String) async throws -> String
}

/// Local rule-engine tier with an optional L2 on-device model bridge for drafts.
/// Next-step suggestions stay on the L1 rule engine; a draft first tries the injected
/// L2 generator and falls back to the L1 rule template when L2 is unavailable or fails.
/// Every path runs on-device; nothing leaves the device.
final class AIService: AIServiceProtocol {
    private let ruleGenerator: DraftGeneratorProtocol
    private let modelGenerator: DraftGeneratorProtocol?

    init(ruleGenerator: DraftGeneratorProtocol = RuleDraftGenerator(),
         modelGenerator: DraftGeneratorProtocol? = nil) {
        self.ruleGenerator = ruleGenerator
        self.modelGenerator = modelGenerator
    }

    func suggestNextStep(for deal: Deal, history: [Interaction]) async throws -> NextStepSuggestion {
        // TODO(later): prefer on-device/native framework; fall back to secure backend only if needed.
        let calendar = Calendar.current
        let now = Date()
        let daysStale = max(0, calendar.dateComponents([.day], from: deal.updatedAt, to: now).day ?? 0)
        let offset = deal.stage.defaultFollowUpOffsetDays
        let settled = deal.stage == .closed || deal.stage == .paid
        let stalled = !settled && daysStale > max(offset, 3)

        let dueAt: Date
        if settled {
            dueAt = now
        } else if stalled {
            dueAt = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        } else {
            dueAt = calendar.date(byAdding: .day, value: offset, to: now) ?? now
        }

        var rationale = "Default cadence for stage \(deal.stage.rawValue)."
        if let last = history.sorted(by: { $0.date > $1.date }).first {
            rationale += " Last contact via \(last.channel.displayName)."
        }
        if stalled {
            rationale += " Unchanged for \(daysStale) days, so a sooner nudge makes sense."
        }

        return NextStepSuggestion(
            action: Self.action(for: deal.stage),
            suggestedDueAt: dueAt,
            rationale: rationale,
            generatedBy: "native"
        )
    }

    private static func action(for stage: DealStage) -> String {
        switch stage {
        case .lead:       return "Send an introductory follow-up and qualify the client's need."
        case .proposal:   return "Follow up on the proposal and answer any open questions."
        case .quote:      return "Check whether the quote was reviewed and clarify pricing questions."
        case .contract:   return "Push to finalize and sign the contract."
        case .delivering: return "Share a progress update and confirm the next milestones."
        case .invoiced:   return "Confirm the invoice was received and answer billing questions."
        case .paid:       return "Thank the client and ask for a referral or repeat work."
        case .atRisk:     return "Reach out promptly to recover the stalled engagement."
        case .closed:     return "No active step; keep the relationship warm."
        }
    }

    func draftReengagementMessage(for client: Client, context: String) async throws -> String {
        // Prefer the injected on-device model when it can serve the request; fall back to
        // the local rule template otherwise. The result is always an editable draft that
        // the user reviews before sending; it is never auto-sent.
        if let modelGenerator,
           let result = await modelGenerator.draft(clientName: client.name, context: context) {
            return result.text
        }
        return await ruleGenerator.draft(clientName: client.name, context: context)?.text
            ?? "Hi \(client.name), just checking in."
    }
}

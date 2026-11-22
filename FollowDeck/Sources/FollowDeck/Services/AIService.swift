//
//  AIService.swift
//  FollowDeck
//
//  AI capability tiers (see 01-生态战略原则与方向框架 §AI 应用方向, 05 立项书 §9):
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

/// Placeback until native Apple Intelligence / on-device or secure backend integration is wired on macOS.
final class AIService: AIServiceProtocol {
    func suggestNextStep(for deal: Deal, history: [Interaction]) async throws -> NextStepSuggestion {
        // TODO(macOS): prefer on-device/native framework; fall back to secure backend only if needed.
        let offset = deal.stage.defaultFollowUpOffsetDays
        let dueAt = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return NextStepSuggestion(
            action: "Follow up on \(deal.title) (\(deal.stage.rawValue)).",
            suggestedDueAt: dueAt,
            rationale: "Default cadence for stage \(deal.stage.rawValue).",
            generatedBy: "native"
        )
    }

    func draftReengagementMessage(for client: Client, context: String) async throws -> String {
        // TODO(macOS): produce an editable draft; never auto-send.
        return "Hi \(client.name), just checking in on \(context). Let me know if you need anything from me."
    }
}

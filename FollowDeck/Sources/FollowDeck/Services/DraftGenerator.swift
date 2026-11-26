//
//  DraftGenerator.swift
//  FollowDeck
//
//  Backing strategies for editable re-engagement drafts. The on-device model bridge
//  is injected behind this protocol so the L1 rule-engine fallback stays pure and
//  unit-testable off-device, and no model framework leaks into the logic layer.
//
//  SECURITY RED LINE: drafts are generated on-device or by the local rule engine;
//  nothing leaves the device and no API key lives in the client. The user always
//  reviews and edits a draft before it is sent.
//

import Foundation

/// The result of a draft generation attempt, labelled with the backing layer.
struct DraftResult: Equatable {
    let text: String
    /// `native-rule` (L1 local rule engine) or `on-device-model` (L2 system model).
    let generatedBy: String
}

/// A draft-producing layer. Return `nil` when this layer cannot serve the request so
/// the caller falls back to the L1 rule engine.
protocol DraftGeneratorProtocol: AnyObject {
    func draft(clientName: String, context: String) async -> DraftResult?
}

/// L1: local rule engine. Produces a short, editable template that always runs locally.
final class RuleDraftGenerator: DraftGeneratorProtocol {
    func draft(clientName: String, context: String) async -> DraftResult? {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = trimmed.isEmpty ? "your current work" : trimmed
        return DraftResult(
            text: "Hi \(clientName), just checking in on \(detail). Let me know if you need anything from me.",
            generatedBy: "native-rule"
        )
    }
}

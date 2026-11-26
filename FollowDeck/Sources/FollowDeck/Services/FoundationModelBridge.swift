//
//  FoundationModelBridge.swift
//  FollowDeck
//
//  L2 bridge to the on-device Apple Foundation Model (FoundationModels framework,
//  iOS 26.0+, Apple-Intelligence-capable device with the model available). The whole
//  bridge is compiled only when the SDK ships the framework and gated at run time to
//  iOS 26+. Every unavailable device, missing model, generation error or empty response
//  returns nil so the caller falls back to the L1 rule engine. Generation stays
//  on-device; no record or prompt leaves the device.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
final class FoundationModelBridge: DraftGeneratorProtocol {

    func draft(clientName: String, context: String) async -> DraftResult? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let instructions = """
        You write short, polite follow-up messages for a lightweight CRM app.
        Keep the message to one or two sentences and use the client's name naturally.
        Do not add a signature, placeholders, markdown, or any extra commentary.
        """
        let session = LanguageModelSession(instructions: instructions)
        let detail = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = "Draft a short re-engagement message for \(clientName) about: \(detail.isEmpty ? "the current work" : detail)."

        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return DraftResult(text: text, generatedBy: "on-device-model")
        } catch {
            return nil
        }
    }
}
#endif

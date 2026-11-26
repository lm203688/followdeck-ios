//
//  AIServiceAssembly.swift
//  FollowDeck
//
//  Composition root for the AI service. Wires the optional L2 on-device model bridge on
//  iOS 26+ where the FoundationModels framework exists and the device supports Apple
//  Intelligence; on every older OS the L1 rule engine serves all requests. The bridge
//  itself re-checks model availability and falls back internally when generation fails.
//

import Foundation

enum AIServiceAssembly {
    static let shared: AIServiceProtocol = make()

    private static func make() -> AIServiceProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AIService(modelGenerator: FoundationModelBridge())
        }
        #endif
        return AIService()
    }
}

//
//  PersistenceController.swift
//  FollowDeck
//
//  Shared SwiftData container so the app, App Intents and previews all use the
//  same local store. Local-first; CloudKit and sync are not enabled here.
//

import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared: PersistenceController = {
        do {
            return try PersistenceController()
        } catch {
            fatalError("Unable to initialize SwiftData ModelContainer: \(error)")
        }
    }()

    let container: ModelContainer

    private init() throws {
        container = try ModelContainer(
            for: SDClient.self, SDDeal.self, SDFollowUp.self, SDInteraction.self
        )
    }

    var context: ModelContext { container.mainContext }

    /// A fresh StoreProtocol view over the shared main context.
    func makeStore() -> StoreProtocol {
        SwiftDataStore(context: context)
    }
}

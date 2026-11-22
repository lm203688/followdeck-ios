//
//  Entities.swift
//  FollowDeck
//
//  AppEntity representations of the local records, so Siri and Shortcuts can
//  pick a real client / follow-up / deal instead of entering a raw UUID string.
//  Queries read through the shared MainActor store.
//

import AppIntents
import Foundation

// MARK: - Client

struct ClientEntity: AppEntity {
    let id: UUID
    let name: String
    let email: String?

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Client"
    static var defaultQuery = ClientEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: email.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    init(id: UUID, name: String, email: String?) {
        self.id = id
        self.name = name
        self.email = email
    }

    init(_ client: Client) {
        self.init(id: client.id, name: client.name, email: client.email)
    }
}

struct ClientEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ClientEntity] {
        await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            let wanted = Set(identifiers)
            return store.clients().filter { wanted.contains($0.id) }.map(ClientEntity.init)
        }
    }

    func suggestedEntities() async throws -> [ClientEntity] {
        await MainActor.run {
            PersistenceController.shared.makeStore().clients().map(ClientEntity.init)
        }
    }
}

// MARK: - Follow-up

struct FollowUpEntity: AppEntity {
    let id: UUID
    let note: String
    let dueAt: Date
    let status: FollowUpStatus

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Follow-up"
    static var defaultQuery = FollowUpEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: note),
            subtitle: LocalizedStringResource(stringLiteral: "\(DisplayFormat.date(dueAt)) · \(status.displayName)")
        )
    }

    init(id: UUID, note: String, dueAt: Date, status: FollowUpStatus) {
        self.id = id
        self.note = note
        self.dueAt = dueAt
        self.status = status
    }

    init(_ followUp: FollowUp) {
        self.init(id: followUp.id, note: followUp.note, dueAt: followUp.dueAt, status: followUp.status)
    }
}

struct FollowUpEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [FollowUpEntity] {
        await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            let wanted = Set(identifiers)
            return store.allFollowUps().filter { wanted.contains($0.id) }.map(FollowUpEntity.init)
        }
    }

    func suggestedEntities() async throws -> [FollowUpEntity] {
        await MainActor.run {
            PersistenceController.shared.makeStore().allFollowUps().map(FollowUpEntity.init)
        }
    }
}

// MARK: - Deal

struct DealEntity: AppEntity {
    let id: UUID
    let title: String
    let stage: DealStage

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Deal"
    static var defaultQuery = DealEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: stage.displayName)
        )
    }

    init(id: UUID, title: String, stage: DealStage) {
        self.id = id
        self.title = title
        self.stage = stage
    }

    init(_ deal: Deal) {
        self.init(id: deal.id, title: deal.title, stage: deal.stage)
    }
}

struct DealEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DealEntity] {
        await MainActor.run {
            let store = PersistenceController.shared.makeStore()
            let wanted = Set(identifiers)
            return store.allDeals().filter { wanted.contains($0.id) }.map(DealEntity.init)
        }
    }

    func suggestedEntities() async throws -> [DealEntity] {
        await MainActor.run {
            PersistenceController.shared.makeStore().allDeals().map(DealEntity.init)
        }
    }
}

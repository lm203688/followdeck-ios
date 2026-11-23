//
//  SwiftDataStore.swift
//  FollowDeck
//
//  SwiftData-backed StoreProtocol implementation. Domain structs in Models.swift stay
//  pure and portable; this layer maps between them and SwiftData @Model records.
//  Local-first; no CloudKit or sync is enabled here.
//

import Foundation
import SwiftData

// MARK: - SwiftData records

@Model final class SDClient {
    @Attribute(.unique) var id: UUID
    var name: String
    var phone: String?
    var email: String?
    var tags: [String]
    var notes: String
    var avatarAssetName: String?
    var createdAt: Date
    var lastContactedAt: Date?
    var status: String

    init(id: UUID, name: String, phone: String?, email: String?, tags: [String], notes: String,
         avatarAssetName: String?, createdAt: Date, lastContactedAt: Date?, status: String) {
        self.id = id; self.name = name; self.phone = phone; self.email = email
        self.tags = tags; self.notes = notes; self.avatarAssetName = avatarAssetName
        self.createdAt = createdAt; self.lastContactedAt = lastContactedAt; self.status = status
    }
}

@Model final class SDDeal {
    @Attribute(.unique) var id: UUID
    var clientID: UUID
    var title: String
    var stageRaw: String
    var amount: Decimal?
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    var nextAction: String?
    var nextDueAt: Date?
    var ownerNote: String

    init(id: UUID, clientID: UUID, title: String, stageRaw: String, amount: Decimal?, currency: String,
         createdAt: Date, updatedAt: Date, nextAction: String?, nextDueAt: Date?, ownerNote: String) {
        self.id = id; self.clientID = clientID; self.title = title; self.stageRaw = stageRaw
        self.amount = amount; self.currency = currency; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.nextAction = nextAction; self.nextDueAt = nextDueAt
        self.ownerNote = ownerNote
    }
}

@Model final class SDFollowUp {
    @Attribute(.unique) var id: UUID
    var dealID: UUID?
    var clientID: UUID
    var typeRaw: String
    var note: String
    var dueAt: Date
    var statusRaw: String
    var channelRaw: String
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID, dealID: UUID?, clientID: UUID, typeRaw: String, note: String, dueAt: Date,
         statusRaw: String, channelRaw: String, createdAt: Date, completedAt: Date?) {
        self.id = id; self.dealID = dealID; self.clientID = clientID; self.typeRaw = typeRaw
        self.note = note; self.dueAt = dueAt; self.statusRaw = statusRaw; self.channelRaw = channelRaw
        self.createdAt = createdAt; self.completedAt = completedAt
    }
}

@Model final class SDInteraction {
    @Attribute(.unique) var id: UUID
    var clientID: UUID
    var dealID: UUID?
    var channelRaw: String
    var summary: String
    var date: Date
    var durationMinutes: Int?

    init(id: UUID, clientID: UUID, dealID: UUID?, channelRaw: String, summary: String,
         date: Date, durationMinutes: Int?) {
        self.id = id; self.clientID = clientID; self.dealID = dealID; self.channelRaw = channelRaw
        self.summary = summary; self.date = date; self.durationMinutes = durationMinutes
    }
}

// MARK: - Mapping

private extension SDClient {
    func toClient() -> Client {
        Client(id: id, name: name, phone: phone, email: email, tags: tags, notes: notes,
               avatarAssetName: avatarAssetName, createdAt: createdAt,
               lastContactedAt: lastContactedAt, status: status)
    }
}

private extension Client {
    func toSD() -> SDClient {
        SDClient(id: id, name: name, phone: phone, email: email, tags: tags, notes: notes,
                 avatarAssetName: avatarAssetName, createdAt: createdAt,
                 lastContactedAt: lastContactedAt, status: status)
    }
}

private extension SDDeal {
    func toDeal() -> Deal {
        Deal(id: id, clientID: clientID, title: title,
             stage: DealStage(rawValue: stageRaw) ?? .lead, amount: amount, currency: currency,
             createdAt: createdAt, updatedAt: updatedAt, nextAction: nextAction,
             nextDueAt: nextDueAt, ownerNote: ownerNote)
    }
}

private extension Deal {
    func toSD() -> SDDeal {
        SDDeal(id: id, clientID: clientID, title: title, stageRaw: stage.rawValue, amount: amount,
               currency: currency, createdAt: createdAt, updatedAt: updatedAt, nextAction: nextAction,
               nextDueAt: nextDueAt, ownerNote: ownerNote)
    }
}

private extension SDFollowUp {
    func toFollowUp() -> FollowUp {
        FollowUp(id: id, dealID: dealID, clientID: clientID,
                 type: FollowUpType(rawValue: typeRaw) ?? .followUp, note: note, dueAt: dueAt,
                 status: FollowUpStatus(rawValue: statusRaw) ?? .pending,
                 channel: Channel(rawValue: channelRaw) ?? .other,
                 createdAt: createdAt, completedAt: completedAt)
    }
}

private extension FollowUp {
    func toSD() -> SDFollowUp {
        SDFollowUp(id: id, dealID: dealID, clientID: clientID, typeRaw: type.rawValue, note: note,
                   dueAt: dueAt, statusRaw: status.rawValue, channelRaw: channel.rawValue,
                   createdAt: createdAt, completedAt: completedAt)
    }
}

private extension SDInteraction {
    func toInteraction() -> Interaction {
        Interaction(id: id, clientID: clientID, dealID: dealID,
                    channel: Channel(rawValue: channelRaw) ?? .other, summary: summary,
                    date: date, durationMinutes: durationMinutes)
    }
}

private extension Interaction {
    func toSD() -> SDInteraction {
        SDInteraction(id: id, clientID: clientID, dealID: dealID, channelRaw: channel.rawValue,
                      summary: summary, date: date, durationMinutes: durationMinutes)
    }
}

// MARK: - Store implementation

final class SwiftDataStore: StoreProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    // Clients
    func clients() -> [Client] { fetch(SDClient.self).map { $0.toClient() } }

    func client(id: UUID) -> Client? {
        fetch(SDClient.self).first { $0.id == id }?.toClient()
    }

    func addClient(_ client: Client) { context.insert(client.toSD()) }

    func updateClient(_ client: Client) {
        guard let record = fetch(SDClient.self).first(where: { $0.id == client.id }) else { return }
        record.name = client.name; record.phone = client.phone; record.email = client.email
        record.tags = client.tags; record.notes = client.notes
        record.avatarAssetName = client.avatarAssetName
        record.lastContactedAt = client.lastContactedAt; record.status = client.status
    }

    func deleteClient(id: UUID) {
        guard let record = fetch(SDClient.self).first(where: { $0.id == id }) else { return }
        context.delete(record)
        fetch(SDFollowUp.self).filter { $0.clientID == id }.forEach { context.delete($0) }
        fetch(SDDeal.self).filter { $0.clientID == id }.forEach { context.delete($0) }
        fetch(SDInteraction.self).filter { $0.clientID == id }.forEach { context.delete($0) }
    }

    // Deals
    func allDeals() -> [Deal] { fetch(SDDeal.self).map { $0.toDeal() } }

    func deals(for clientID: UUID) -> [Deal] {
        allDeals().filter { $0.clientID == clientID }
    }

    func addDeal(_ deal: Deal) { context.insert(deal.toSD()) }

    func updateDeal(_ deal: Deal) {
        guard let record = fetch(SDDeal.self).first(where: { $0.id == deal.id }) else { return }
        record.clientID = deal.clientID; record.title = deal.title
        record.stageRaw = deal.stage.rawValue; record.amount = deal.amount
        record.currency = deal.currency; record.updatedAt = deal.updatedAt
        record.nextAction = deal.nextAction; record.nextDueAt = deal.nextDueAt
        record.ownerNote = deal.ownerNote
    }

    func deleteDeal(id: UUID) {
        guard let record = fetch(SDDeal.self).first(where: { $0.id == id }) else { return }
        context.delete(record)
    }

    // Follow-ups
    func pendingFollowUps() -> [FollowUp] {
        allFollowUps().filter { $0.status == .pending }.sorted { $0.dueAt < $1.dueAt }
    }

    func allFollowUps() -> [FollowUp] {
        fetch(SDFollowUp.self).map { $0.toFollowUp() }.sorted { $0.dueAt < $1.dueAt }
    }

    func addFollowUp(_ followUp: FollowUp) { context.insert(followUp.toSD()) }

    func updateFollowUp(_ followUp: FollowUp) {
        guard let record = fetch(SDFollowUp.self).first(where: { $0.id == followUp.id }) else { return }
        record.dealID = followUp.dealID; record.clientID = followUp.clientID
        record.typeRaw = followUp.type.rawValue; record.note = followUp.note
        record.dueAt = followUp.dueAt; record.statusRaw = followUp.status.rawValue
        record.channelRaw = followUp.channel.rawValue; record.completedAt = followUp.completedAt
    }

    func completeFollowUp(id: UUID, at: Date) {
        guard let record = fetch(SDFollowUp.self).first(where: { $0.id == id }) else { return }
        record.statusRaw = FollowUpStatus.done.rawValue
        record.completedAt = at
    }

    func deleteFollowUp(id: UUID) {
        guard let record = fetch(SDFollowUp.self).first(where: { $0.id == id }) else { return }
        context.delete(record)
    }

    // Interactions
    func addInteraction(_ interaction: Interaction) { context.insert(interaction.toSD()) }

    func interactions(for clientID: UUID) -> [Interaction] {
        fetch(SDInteraction.self).map { $0.toInteraction() }
            .filter { $0.clientID == clientID }.sorted { $0.date > $1.date }
    }

    func allInteractions() -> [Interaction] {
        fetch(SDInteraction.self).map { $0.toInteraction() }.sorted { $0.date > $1.date }
    }
}

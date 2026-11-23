//
//  Store.swift
//  FollowDeck
//
//  Data store protocol. The concrete implementation will use SwiftData (or Core Data)
//  on macOS; this protocol keeps features decoupled from the persistence choice.
//

import Foundation
import SwiftUI

protocol StoreProtocol: AnyObject {
    // Clients
    func clients() -> [Client]
    func client(id: UUID) -> Client?
    func addClient(_ client: Client)
    func updateClient(_ client: Client)
    func deleteClient(id: UUID)

    // Deals
    func allDeals() -> [Deal]
    func deals(for clientID: UUID) -> [Deal]
    func addDeal(_ deal: Deal)
    func updateDeal(_ deal: Deal)
    func deleteDeal(id: UUID)

    // Follow-ups
    func pendingFollowUps() -> [FollowUp]
    func allFollowUps() -> [FollowUp]
    func addFollowUp(_ followUp: FollowUp)
    func updateFollowUp(_ followUp: FollowUp)
    func completeFollowUp(id: UUID, at: Date)
    func deleteFollowUp(id: UUID)

    // Interactions
    func addInteraction(_ interaction: Interaction)
    func interactions(for clientID: UUID) -> [Interaction]
    func allInteractions() -> [Interaction]
}

/// In-memory placeholder used until the persistence layer is wired on macOS.
final class InMemoryStore: ObservableObject, StoreProtocol {
    private var clientList: [Client] = []
    private var dealList: [Deal] = []
    private var followUpList: [FollowUp] = []
    private var interactionList: [Interaction] = []

    func clients() -> [Client] { clientList }

    func client(id: UUID) -> Client? { clientList.first { $0.id == id } }

    func addClient(_ client: Client) { clientList.append(client) }

    func updateClient(_ client: Client) {
        guard let index = clientList.firstIndex(where: { $0.id == client.id }) else { return }
        clientList[index] = client
    }

    func deleteClient(id: UUID) {
        clientList.removeAll { $0.id == id }
        followUpList.removeAll { $0.clientID == id }
        dealList.removeAll { $0.clientID == id }
        interactionList.removeAll { $0.clientID == id }
    }

    func allDeals() -> [Deal] { dealList }

    func deals(for clientID: UUID) -> [Deal] { dealList.filter { $0.clientID == clientID } }

    func addDeal(_ deal: Deal) { dealList.append(deal) }

    func updateDeal(_ deal: Deal) {
        guard let index = dealList.firstIndex(where: { $0.id == deal.id }) else { return }
        dealList[index] = deal
    }

    func deleteDeal(id: UUID) { dealList.removeAll { $0.id == id } }

    func pendingFollowUps() -> [FollowUp] {
        followUpList.filter { $0.status == .pending }.sorted { $0.dueAt < $1.dueAt }
    }

    func allFollowUps() -> [FollowUp] {
        followUpList.sorted { $0.dueAt < $1.dueAt }
    }

    func addFollowUp(_ followUp: FollowUp) { followUpList.append(followUp) }

    func updateFollowUp(_ followUp: FollowUp) {
        guard let index = followUpList.firstIndex(where: { $0.id == followUp.id }) else { return }
        followUpList[index] = followUp
    }

    func completeFollowUp(id: UUID, at: Date) {
        guard let index = followUpList.firstIndex(where: { $0.id == id }) else { return }
        followUpList[index].status = .done
        followUpList[index].completedAt = at
    }

    func deleteFollowUp(id: UUID) {
        followUpList.removeAll { $0.id == id }
    }

    func addInteraction(_ interaction: Interaction) { interactionList.append(interaction) }

    func interactions(for clientID: UUID) -> [Interaction] {
        interactionList.filter { $0.clientID == clientID }.sorted { $0.date > $1.date }
    }

    func allInteractions() -> [Interaction] {
        interactionList.sorted { $0.date > $1.date }
    }
}

/// ObservableObject wrapper so SwiftUI can observe a `StoreProtocol` behind one concrete type.
/// Write methods forward and announce a change; persistence choice lives in the wrapped store.
@MainActor
final class StoreBridge: ObservableObject {
    let store: StoreProtocol
    private let reminder: ReminderServiceProtocol
    private let spotlight: SpotlightIndexerProtocol

    init(store: StoreProtocol,
         reminder: ReminderServiceProtocol = ReminderService.shared,
         spotlight: SpotlightIndexerProtocol = SpotlightIndexer.shared) {
        self.store = store
        self.reminder = reminder
        self.spotlight = spotlight
    }

    // MARK: Clients
    func clients() -> [Client] { store.clients() }
    func client(id: UUID) -> Client? { store.client(id: id) }
    func addClient(_ client: Client) { objectWillChange.send(); store.addClient(client); spotlight.index(client: client) }
    func updateClient(_ client: Client) { objectWillChange.send(); store.updateClient(client); spotlight.index(client: client) }
    func deleteClient(id: UUID) {
        objectWillChange.send()
        let clientDeals = store.deals(for: id)
        store.allFollowUps().filter { $0.clientID == id }.forEach { reminder.cancel(id: $0.id) }
        store.deleteClient(id: id)
        spotlight.removeRecord(id: id)
        clientDeals.forEach { spotlight.removeRecord(id: $0.id) }
    }

    // MARK: Deals
    func allDeals() -> [Deal] { store.allDeals() }
    func deals(for clientID: UUID) -> [Deal] { store.deals(for: clientID) }
    func addDeal(_ deal: Deal) { objectWillChange.send(); store.addDeal(deal); spotlight.index(deal: deal) }
    func updateDeal(_ deal: Deal) { objectWillChange.send(); store.updateDeal(deal); spotlight.index(deal: deal) }
    func deleteDeal(id: UUID) { objectWillChange.send(); store.deleteDeal(id: id); spotlight.removeRecord(id: id) }

    // MARK: Follow-ups
    func pendingFollowUps() -> [FollowUp] { store.pendingFollowUps() }
    func allFollowUps() -> [FollowUp] { store.allFollowUps() }
    func addFollowUp(_ followUp: FollowUp) { objectWillChange.send(); store.addFollowUp(followUp); reminder.schedule(followUp) }
    func updateFollowUp(_ followUp: FollowUp) { objectWillChange.send(); store.updateFollowUp(followUp); reminder.reschedule(followUp) }
    func completeFollowUp(id: UUID, at: Date) { objectWillChange.send(); store.completeFollowUp(id: id, at: at); reminder.cancel(id: id) }
    func deleteFollowUp(id: UUID) { objectWillChange.send(); store.deleteFollowUp(id: id); reminder.cancel(id: id) }

    // MARK: Interactions
    func addInteraction(_ interaction: Interaction) { objectWillChange.send(); store.addInteraction(interaction) }
    func interactions(for clientID: UUID) -> [Interaction] { store.interactions(for: clientID) }
    func allInteractions() -> [Interaction] { store.allInteractions() }
}

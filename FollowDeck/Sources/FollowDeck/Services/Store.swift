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
    func addClient(_ client: Client)
    func updateClient(_ client: Client)
    func deleteClient(id: UUID)

    // Deals
    func deals(for clientID: UUID) -> [Deal]
    func addDeal(_ deal: Deal)
    func updateDeal(_ deal: Deal)
    func deleteDeal(id: UUID)

    // Follow-ups
    func pendingFollowUps() -> [FollowUp]
    func addFollowUp(_ followUp: FollowUp)
    func updateFollowUp(_ followUp: FollowUp)
    func completeFollowUp(id: UUID, at: Date)

    // Interactions
    func addInteraction(_ interaction: Interaction)
    func interactions(for clientID: UUID) -> [Interaction]
}

/// In-memory placeholder used until the persistence layer is wired on macOS.
final class InMemoryStore: ObservableObject, StoreProtocol {
    private var clients: [Client] = []
    private var deals: [Deal] = []
    private var followUps: [FollowUp] = []
    private var interactions: [Interaction] = []

    func clients() -> [Client] { clients }

    func addClient(_ client: Client) { clients.append(client) }

    func updateClient(_ client: Client) {
        guard let index = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[index] = client
    }

    func deleteClient(id: UUID) { clients.removeAll { $0.id == id } }

    func deals(for clientID: UUID) -> [Deal] { deals.filter { $0.clientID == clientID } }

    func addDeal(_ deal: Deal) { deals.append(deal) }

    func updateDeal(_ deal: Deal) {
        guard let index = deals.firstIndex(where: { $0.id == deal.id }) else { return }
        deals[index] = deal
    }

    func deleteDeal(id: UUID) { deals.removeAll { $0.id == id } }

    func pendingFollowUps() -> [FollowUp] {
        followUps.filter { $0.status == .pending }.sorted { $0.dueAt < $1.dueAt }
    }

    func addFollowUp(_ followUp: FollowUp) { followUps.append(followUp) }

    func updateFollowUp(_ followUp: FollowUp) {
        guard let index = followUps.firstIndex(where: { $0.id == followUp.id }) else { return }
        followUps[index] = followUp
    }

    func completeFollowUp(id: UUID, at: Date) {
        guard let index = followUps.firstIndex(where: { $0.id == id }) else { return }
        followUps[index].status = .done
        followUps[index].completedAt = at
    }

    func addInteraction(_ interaction: Interaction) { interactions.append(interaction) }

    func interactions(for clientID: UUID) -> [Interaction] {
        interactions.filter { $0.clientID == clientID }.sorted { $0.date > $1.date }
    }
}

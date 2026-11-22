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
    private var clientList: [Client] = []
    private var dealList: [Deal] = []
    private var followUpList: [FollowUp] = []
    private var interactionList: [Interaction] = []

    func clients() -> [Client] { clientList }

    func addClient(_ client: Client) { clientList.append(client) }

    func updateClient(_ client: Client) {
        guard let index = clientList.firstIndex(where: { $0.id == client.id }) else { return }
        clientList[index] = client
    }

    func deleteClient(id: UUID) { clientList.removeAll { $0.id == id } }

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

    func addInteraction(_ interaction: Interaction) { interactionList.append(interaction) }

    func interactions(for clientID: UUID) -> [Interaction] {
        interactionList.filter { $0.clientID == clientID }.sorted { $0.date > $1.date }
    }
}

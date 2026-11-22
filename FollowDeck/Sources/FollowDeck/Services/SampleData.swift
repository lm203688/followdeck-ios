//
//  SampleData.swift
//  FollowDeck
//
//  First-launch sample data. Seeds a small, clearly editable demo set so the
//  app never opens to an empty screen. Seeding only happens when the store has
//  no clients, so real data is never duplicated or overwritten.
//

import Foundation

enum SampleData {
    /// Populate demo records if the store is empty.
    static func seedIfEmpty(store: StoreProtocol) {
        guard store.clients().isEmpty else { return }

        let today = Date()
        let yesterday = today.addingTimeInterval(-86_400)

        let maya = Client(
            name: "Maya Chen",
            email: "maya@example.com",
            notes: "Independent design consultant",
            status: "active"
        )
        let jordan = Client(
            name: "Jordan Lee",
            email: "jordan@example.com",
            notes: "Speaking engagement follow-up",
            status: "active"
        )
        store.addClient(maya)
        store.addClient(jordan)

        store.addDeal(Deal(clientID: maya.id, title: "Brand refresh", stage: .proposal))

        store.addFollowUp(FollowUp(clientID: maya.id, note: "Send the proposal", dueAt: today))
        store.addFollowUp(FollowUp(clientID: jordan.id, note: "Follow up on the invoice", dueAt: yesterday))

        store.addInteraction(Interaction(clientID: maya.id, channel: .meeting, summary: "Kickoff call to align on scope"))
        store.addInteraction(Interaction(clientID: jordan.id, channel: .call, summary: "Reviewed upcoming availability"))
    }
}

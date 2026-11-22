//
//  ClientDetailView.swift
//  FollowDeck
//
//  Per-client overview: contact details, follow-ups and deals in one place.
//  A shortcut here pre-selects this client when adding a follow-up.
//

import SwiftUI

struct ClientDetailView: View {
    @EnvironmentObject private var store: StoreBridge
    let clientID: UUID
    @State private var showingAddFollowUp = false

    private var client: Client? { store.client(id: clientID) }
    private var followUps: [FollowUp] {
        store.allFollowUps().filter { $0.clientID == clientID }
    }
    private var deals: [Deal] { store.deals(for: clientID) }

    var body: some View {
        List {
            if let client {
                Section("Contact") {
                    if let email = client.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                    }
                    if let phone = client.phone, !phone.isEmpty {
                        Label(phone, systemImage: "phone")
                    }
                    if !client.tags.isEmpty {
                        Text(client.tags.joined(separator: " · "))
                            .foregroundColor(.secondary)
                    }
                    if !client.notes.isEmpty {
                        Text(client.notes)
                    }
                }

                Section("Follow-ups (\(followUps.count))") {
                    if followUps.isEmpty {
                        Text("No follow-ups yet.").foregroundColor(.secondary)
                    } else {
                        ForEach(followUps) { item in
                            FollowUpRow(followUp: item, tint: .blue)
                        }
                    }
                }

                Section("Deals (\(deals.count))") {
                    if deals.isEmpty {
                        Text("No deals yet.").foregroundColor(.secondary)
                    } else {
                        ForEach(deals) { deal in
                            DealRow(deal: deal)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Client not found",
                    systemImage: "person.slash",
                    description: Text("This client may have been deleted.")
                )
            }
        }
        .navigationTitle(client?.name ?? "Client")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddFollowUp = true
                } label: {
                    Label("Add follow-up", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFollowUp) {
            AddFollowUpView(preselectedClientID: clientID)
        }
    }
}

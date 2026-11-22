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
    @State private var showingAddInteraction = false

    private var client: Client? { store.client(id: clientID) }
    private var followUps: [FollowUp] {
        store.allFollowUps().filter { $0.clientID == clientID }
    }
    private var deals: [Deal] { store.deals(for: clientID) }
    private var interactions: [Interaction] { store.interactions(for: clientID) }

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

                Section("Interactions (\(interactions.count))") {
                    if interactions.isEmpty {
                        Text("No interactions logged yet.").foregroundColor(.secondary)
                    } else {
                        ForEach(interactions) { item in
                            InteractionRow(interaction: item)
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
                Menu {
                    Button("Add follow-up") { showingAddFollowUp = true }
                    Button("Log interaction") { showingAddInteraction = true }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFollowUp) {
            AddFollowUpView(preselectedClientID: clientID)
        }
        .sheet(isPresented: $showingAddInteraction) {
            AddInteractionView(preselectedClientID: clientID)
        }
    }
}

private struct InteractionRow: View {
    let interaction: Interaction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(interaction.channel.displayName).font(.headline)
                Spacer()
                Text(DisplayFormat.dateTime(interaction.date))
                    .font(.caption).foregroundColor(.secondary)
            }
            Text(interaction.summary).font(.subheadline).lineLimit(3)
            if let duration = interaction.durationMinutes {
                Text("\(duration) min").font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

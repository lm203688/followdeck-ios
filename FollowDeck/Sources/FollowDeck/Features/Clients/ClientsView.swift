//
//  ClientsView.swift
//  FollowDeck
//
//  Client roster. Read-only over the store for now; add/edit/detail views follow later.
//

import SwiftUI

struct ClientsView: View {
    @EnvironmentObject private var store: StoreBridge
    @State private var showingAddClient = false
    @State private var showingExport = false
    @State private var searchText = ""

    private var clients: [Client] { ClientSorter.sorted(store.clients()) }

    private var filteredClients: [Client] {
        guard !searchText.isEmpty else { return clients }
        let needle = searchText.lowercased()
        return clients.filter {
            $0.name.lowercased().contains(needle)
            || ($0.email ?? "").lowercased().contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredClients) { client in
                    NavigationLink {
                        ClientDetailView(clientID: client.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.name).font(.headline)
                            HStack(spacing: 8) {
                                if let email = client.email, !email.isEmpty {
                                    Label(email, systemImage: "envelope")
                                }
                                if let phone = client.phone, !phone.isEmpty {
                                    Label(phone, systemImage: "phone")
                                }
                            }
                            .font(.caption).foregroundColor(.secondary)
                            if !client.tags.isEmpty {
                                Text(client.tags.joined(separator: " · "))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.forEach { store.deleteClient(id: filteredClients[$0].id) }
                }
            }
            .searchable(text: $searchText, prompt: "Search clients")
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddClient = true
                    } label: {
                        Label("Add client", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
            .sheet(isPresented: $showingExport) {
                ExportDataView()
            }
            .overlay {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No clients",
                        systemImage: "person.2",
                        description: Text("Add a client to start tracking follow-ups and deals.")
                    )
                }
            }
        }
    }
}

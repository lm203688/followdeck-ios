//
//  AddInteractionView.swift
//  FollowDeck
//
//  Minimal log-interaction form: client, channel, summary and optional duration.
//  Writes through StoreBridge; the client detail timeline refreshes automatically.
//

import SwiftUI

struct AddInteractionView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var selectedClientID: UUID?
    @State private var channel: Channel = .other
    @State private var summary = ""
    @State private var durationText = ""

    init(preselectedClientID: UUID? = nil) {
        _selectedClientID = State(initialValue: preselectedClientID)
    }

    private var clients: [Client] { store.clients() }
    private var trimmedSummary: String { summary.trimmingCharacters(in: .whitespaces) }

    private var duration: Int? {
        let cleaned = durationText.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Int(cleaned)
    }

    private var canSave: Bool { selectedClientID != nil && !trimmedSummary.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No clients yet",
                        systemImage: "person",
                        description: Text("Add a client first, then log an interaction.")
                    )
                } else {
                    Section("Client") {
                        Picker("Client", selection: $selectedClientID) {
                            Text("Select a client").tag(UUID?.none)
                            ForEach(clients) { client in
                                Text(client.name).tag(UUID?.some(client.id))
                            }
                        }
                    }
                    Section("Interaction") {
                        Picker("Channel", selection: $channel) {
                            ForEach(Channel.allCases) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        TextField("Summary", text: $summary, axis: .vertical)
                            .lineLimit(3...5)
                        TextField("Duration (minutes, optional)", text: $durationText)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Log Interaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let clientID = selectedClientID else { return }
        let interaction = Interaction(
            clientID: clientID,
            channel: channel,
            summary: trimmedSummary,
            durationMinutes: duration
        )
        store.addInteraction(interaction)
        dismiss()
    }
}

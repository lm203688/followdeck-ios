//
//  AddDealView.swift
//  FollowDeck
//
//  Minimal create-deal form: pick a client, title, stage and optional amount.
//  Writes through StoreBridge; the Pipeline board and client detail refresh.
//

import SwiftUI

struct AddDealView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var selectedClientID: UUID?
    @State private var title = ""
    @State private var stage: DealStage = .lead
    @State private var amountText = ""

    private var clients: [Client] { store.clients() }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    private var amount: Decimal? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    private var canSave: Bool { selectedClientID != nil && !trimmedTitle.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No clients yet",
                        systemImage: "person",
                        description: Text("Add a client first, then create a deal.")
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
                    Section("Deal") {
                        TextField("Title", text: $title)
                        Picker("Stage", selection: $stage) {
                            ForEach(DealStage.allCases) { stage in
                                Text(stage.displayName).tag(stage)
                            }
                        }
                        TextField("Amount (optional)", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("New Deal")
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
        let deal = Deal(
            clientID: clientID,
            title: trimmedTitle,
            stage: stage,
            amount: amount,
            currency: "USD"
        )
        store.addDeal(deal)
        dismiss()
    }
}

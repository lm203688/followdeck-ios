//
//  AddDealView.swift
//  FollowDeck
//
//  Create or edit a deal: pick a client, title, stage, optional amount,
//  next action, optional due date and owner note.
//  Writes through StoreBridge; the Pipeline board and client detail refresh.
//

import SwiftUI

struct AddDealView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    private let editingDeal: Deal?
    @State private var selectedClientID: UUID?
    @State private var title: String
    @State private var stage: DealStage
    @State private var amountText: String
    @State private var nextActionText: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var ownerNoteText: String

    init(deal: Deal? = nil) {
        self.editingDeal = deal
        _selectedClientID = State(initialValue: deal?.clientID)
        _title = State(initialValue: deal?.title ?? "")
        _stage = State(initialValue: deal?.stage ?? .lead)
        _amountText = State(initialValue: deal?.amount.map { String(describing: $0) } ?? "")
        _nextActionText = State(initialValue: deal?.nextAction ?? "")
        _hasDueDate = State(initialValue: deal?.nextDueAt != nil)
        _dueDate = State(
            initialValue: deal?.nextDueAt
                ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                ?? Date()
        )
        _ownerNoteText = State(initialValue: deal?.ownerNote ?? "")
    }

    private var clients: [Client] { store.clients() }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    private var amount: Decimal? { FormValidators.parsedAmount(amountText) }
    private var amountValid: Bool { FormValidators.isValidAmount(amountText) }

    private var trimmedAction: String {
        nextActionText.trimmingCharacters(in: .whitespaces)
    }
    private var trimmedOwnerNote: String {
        ownerNoteText.trimmingCharacters(in: .whitespaces)
    }
    private var nextAction: String? { trimmedAction.isEmpty ? nil : trimmedAction }
    private var nextDueAt: Date? { hasDueDate ? dueDate : nil }

    private var canSave: Bool {
        selectedClientID != nil && !trimmedTitle.isEmpty && amountValid
    }

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
                        if !amountValid {
                            Text("Enter a number, or leave the amount empty.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Section("Next step") {
                        TextField("Next action (optional)", text: $nextActionText, axis: .vertical)
                            .lineLimit(2...3)
                        Toggle("Set due date", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        }
                        TextField("Owner note (optional)", text: $ownerNoteText, axis: .vertical)
                            .lineLimit(3...5)
                    }
                }
            }
            .navigationTitle(editingDeal == nil ? "New Deal" : "Edit Deal")
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

        if let editingDeal {
            var updated = editingDeal
            updated.clientID = clientID
            updated.title = trimmedTitle
            updated.stage = stage
            updated.amount = amount
            updated.nextAction = nextAction
            updated.nextDueAt = nextDueAt
            updated.ownerNote = trimmedOwnerNote
            updated.updatedAt = Date()
            store.updateDeal(updated)
        } else {
            let deal = Deal(
                clientID: clientID,
                title: trimmedTitle,
                stage: stage,
                amount: amount,
                currency: "USD",
                nextAction: nextAction,
                nextDueAt: nextDueAt,
                ownerNote: trimmedOwnerNote
            )
            store.addDeal(deal)
        }
        dismiss()
    }
}

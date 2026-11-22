//
//  AddFollowUpView.swift
//  FollowDeck
//
//  Minimal create-follow-up form: pick an existing client, write a short note and
//  a due date. Writes through StoreBridge; the Today and Follow-ups boards refresh
//  automatically.
//

import SwiftUI

struct AddFollowUpView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var selectedClientID: UUID?
    @State private var note = ""
    @State private var dueAt: Date =
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    private var clients: [Client] { store.clients() }
    private var canSave: Bool {
        selectedClientID != nil && !note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "No clients yet",
                        systemImage: "person",
                        description: Text("Add a client first, then schedule a follow-up.")
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
                    Section("Follow-up") {
                        TextField("Note", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                        DatePicker("Due", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Follow-up")
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
        let followUp = FollowUp(
            clientID: clientID,
            note: note.trimmingCharacters(in: .whitespaces),
            dueAt: dueAt
        )
        store.addFollowUp(followUp)
        ReminderService().schedule(followUp)
        dismiss()
    }
}

//
//  AddClientView.swift
//  FollowDeck
//
//  Create or edit a client. Writes through the shared store via StoreBridge;
//  the roster refreshes automatically on the next objectWillChange announcement.
//

import SwiftUI

struct AddClientView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    private let editingClient: Client?
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var tagsText: String

    init(client: Client? = nil) {
        self.editingClient = client
        _name = State(initialValue: client?.name ?? "")
        _email = State(initialValue: client?.email ?? "")
        _phone = State(initialValue: client?.phone ?? "")
        _tagsText = State(initialValue: client?.tags.joined(separator: ", ") ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section("Tags") {
                    TextField("Comma-separated tags", text: $tagsText)
                }
            }
            .navigationTitle(editingClient == nil ? "New Client" : "Edit Client")
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
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let emailTrimmed = email.trimmingCharacters(in: .whitespaces)
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespaces)

        if let editingClient {
            var updated = editingClient
            updated.name = trimmedName
            updated.email = emailTrimmed.isEmpty ? nil : emailTrimmed
            updated.phone = phoneTrimmed.isEmpty ? nil : phoneTrimmed
            updated.tags = tags
            store.updateClient(updated)
        } else {
            let client = Client(
                name: trimmedName,
                phone: phoneTrimmed.isEmpty ? nil : phoneTrimmed,
                email: emailTrimmed.isEmpty ? nil : emailTrimmed,
                tags: tags
            )
            store.addClient(client)
        }
        dismiss()
    }
}

//
//  AddClientView.swift
//  FollowDeck
//
//  Minimal create-client form. Writes through the shared store via StoreBridge;
//  the roster refreshes automatically on the next objectWillChange announcement.
//

import SwiftUI

struct AddClientView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var tagsText = ""

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
            .navigationTitle("New Client")
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
        let client = Client(
            name: trimmedName,
            phone: phoneTrimmed.isEmpty ? nil : phoneTrimmed,
            email: emailTrimmed.isEmpty ? nil : emailTrimmed,
            tags: tags
        )
        store.addClient(client)
        dismiss()
    }
}

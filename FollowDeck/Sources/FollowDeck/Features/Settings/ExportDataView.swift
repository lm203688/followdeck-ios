//
//  ExportDataView.swift
//  FollowDeck
//
//  Local-only export sheet: builds a JSON snapshot plus contacts / follow-ups CSV
//  tables of every record on device and hands them to the system share sheet.
//  No network call, account, or paywall; the Pro branding and any paid export
//  destination are reserved for later.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportDataView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var jsonURL: URL?
    @State private var clientsCSVURL: URL?
    @State private var followUpsCSVURL: URL?
    @State private var exportError: String?
    @State private var counts: (clients: Int, deals: Int, followUps: Int, interactions: Int)?
    @State private var showRestoreConfirmation = false
    @State private var showImporter = false
    @State private var restoreMessage: String?
    @State private var restoreError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Clients", value: count(\.clients))
                    LabeledContent("Deals", value: count(\.deals))
                    LabeledContent("Follow-ups", value: count(\.followUps))
                    LabeledContent("Interactions", value: count(\.interactions))
                } header: {
                    Text("In this export")
                }

                Section {
                    Text("A JSON snapshot of everything stored on this device, plus CSV tables for clients and follow-ups that open in a spreadsheet. Files never leave your device until you choose where to share them.")
                        .foregroundColor(.secondary)
                } header: {
                    Text("How it works")
                }

                Section {
                    if let exportError {
                        Text(exportError).foregroundColor(.red)
                    } else {
                        if let jsonURL {
                            ShareLink(item: jsonURL, preview: SharePreview("FollowDeck JSON export")) {
                                Label("Share JSON file", systemImage: "square.and.arrow.up")
                            }
                        }
                        if let clientsCSVURL {
                            ShareLink(item: clientsCSVURL, preview: SharePreview("Clients CSV")) {
                                Label("Share clients CSV", systemImage: "tablecells")
                            }
                        }
                        if let followUpsCSVURL {
                            ShareLink(item: followUpsCSVURL, preview: SharePreview("Follow-ups CSV")) {
                                Label("Share follow-ups CSV", systemImage: "tablecells")
                            }
                        }
                        if jsonURL == nil && clientsCSVURL == nil && followUpsCSVURL == nil {
                            HStack {
                                ProgressView()
                                Text("Preparing export…")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showRestoreConfirmation = true
                    } label: {
                        Label("Restore from JSON backup", systemImage: "arrow.down.circle")
                    }
                    if let restoreMessage {
                        Text(restoreMessage).foregroundColor(.green)
                    }
                    if let restoreError {
                        Text(restoreError).foregroundColor(.red)
                    }
                } header: {
                    Text("Restore")
                } footer: {
                    Text("Restoring replaces every client, deal, follow-up and interaction currently on this device with the selected backup file.")
                }
            }
            .navigationTitle("Export data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: prepareExport)
            .alert("Replace current data?", isPresented: $showRestoreConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Restore", role: .destructive) { showImporter = true }
            } message: {
                Text("This erases the clients, deals, follow-ups and interactions currently on this device and replaces them with the backup file you choose.")
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleImport(result)
            }
        }
    }

    private func count(_ keyPath: KeyPath<(clients: Int, deals: Int, followUps: Int, interactions: Int), Int>) -> String {
        guard let counts else { return "—" }
        return String(counts[keyPath: keyPath])
    }

    private func prepareExport() {
        guard jsonURL == nil else { return }
        let snapshot = ExportBuilder.snapshot(from: store.store)
        counts = (snapshot.clients.count, snapshot.deals.count,
                  snapshot.followUps.count, snapshot.interactions.count)
        do {
            let jsonFile = try ExportBuilder.makeFile(from: store.store)
            jsonURL = try writeTemp(jsonFile)

            let clientsFile = ExportBuilder.clientsCSVFile(from: store.store)
            clientsCSVURL = try writeTemp(clientsFile)

            let followUpsFile = ExportBuilder.followUpsCSVFile(from: store.store)
            followUpsCSVURL = try writeTemp(followUpsFile)
        } catch {
            exportError = "Could not prepare the export. Please try again."
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let parsed = try ImportParser.parse(data: data)
            store.restore(parsed)
            restoreError = nil
            refreshCounts()
            let dropped = parsed.droppedDealIDs.count + parsed.droppedFollowUpIDs.count + parsed.droppedInteractionIDs.count
            var message = "Restored \(parsed.clients.count) clients, \(parsed.deals.count) deals, \(parsed.followUps.count) follow-ups and \(parsed.interactions.count) interactions."
            if dropped > 0 {
                message += " \(dropped) orphaned record(s) were skipped."
            }
            restoreMessage = message
        } catch {
            restoreMessage = nil
            restoreError = Self.importErrorText(error)
        }
    }

    private func refreshCounts() {
        let snapshot = ExportBuilder.snapshot(from: store.store)
        counts = (snapshot.clients.count, snapshot.deals.count,
                  snapshot.followUps.count, snapshot.interactions.count)
    }

    private static func importErrorText(_ error: Error) -> String {
        guard let importError = error as? ImportError else {
            return "Could not read the backup file. Please try another file."
        }
        switch importError {
        case .invalidJSON: return "That file is not valid JSON."
        case .incompatibleSchema: return "That file does not look like a FollowDeck backup."
        case .emptySnapshot: return "The backup contains no clients."
        }
    }

    private func writeTemp(_ file: ExportedFile) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
        try file.data.write(to: url, options: .atomic)
        return url
    }
}

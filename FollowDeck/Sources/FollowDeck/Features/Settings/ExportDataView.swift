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

struct ExportDataView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var jsonURL: URL?
    @State private var clientsCSVURL: URL?
    @State private var followUpsCSVURL: URL?
    @State private var exportError: String?
    @State private var counts: (clients: Int, deals: Int, followUps: Int, interactions: Int)?

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
            }
            .navigationTitle("Export data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: prepareExport)
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

    private func writeTemp(_ file: ExportedFile) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
        try file.data.write(to: url, options: .atomic)
        return url
    }
}

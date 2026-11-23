//
//  ExportDataView.swift
//  FollowDeck
//
//  Local-only export sheet: builds a JSON snapshot of every record on device and hands it
//  to the system share sheet. No network call, no account, no paywall; the Pro branding
//  and any paid export destination are reserved for later.
//

import SwiftUI

struct ExportDataView: View {
    @EnvironmentObject private var store: StoreBridge
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
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
                    Text("A JSON snapshot of everything stored on this device. The file never leaves your device until you choose where to share it.")
                        .foregroundColor(.secondary)
                } header: {
                    Text("How it works")
                }

                Section {
                    if let exportError {
                        Text(exportError).foregroundColor(.red)
                    } else if let exportURL {
                        ShareLink(item: exportURL, preview: SharePreview("FollowDeck export")) {
                            Label("Share JSON file", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        HStack {
                            ProgressView()
                            Text("Preparing export…")
                                .foregroundColor(.secondary)
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
        guard exportURL == nil else { return }
        let snapshot = ExportBuilder.snapshot(from: store.store)
        counts = (snapshot.clients.count, snapshot.deals.count,
                  snapshot.followUps.count, snapshot.interactions.count)
        do {
            let file = try ExportBuilder.makeFile(from: store.store)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.fileName)
            try file.data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportError = "Could not prepare the export. Please try again."
        }
    }
}

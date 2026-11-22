//
//  PipelineView.swift
//  FollowDeck
//
//  Deal pipeline grouped by stage. Read-only over the store for now; drag-and-drop
//  stage moves and stalled/at-risk highlighting land in a later iteration.
//

import SwiftUI

struct PipelineView: View {
    @EnvironmentObject private var store: StoreBridge
    @State private var showingAddDeal = false

    private var deals: [Deal] { store.allDeals() }

    var body: some View {
        NavigationStack {
            List {
                ForEach(DealStage.allCases, id: \.self) { stage in
                    let stageDeals = deals.filter { $0.stage == stage }
                    if !stageDeals.isEmpty {
                        Section(stage.displayName) {
                            ForEach(stageDeals) { deal in
                                DealRow(deal: deal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pipeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddDeal = true
                    } label: {
                        Label("Add deal", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDeal) {
                AddDealView()
            }
            .overlay {
                if deals.isEmpty {
                    ContentUnavailableView(
                        "No deals yet",
                        systemImage: "tray",
                        description: Text("Create a deal for a client to track it through the stages.")
                    )
                }
            }
        }
    }
}

struct DealRow: View {
    @EnvironmentObject private var store: StoreBridge
    let deal: Deal

    private var clientName: String {
        store.client(id: deal.clientID)?.name ?? "Unknown client"
    }

    private var amountText: String? {
        guard let amount = deal.amount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = deal.currency
        return formatter.string(from: amount as NSNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(deal.title).font(.headline)
                Spacer()
                if let amountText { Text(amountText).font(.subheadline).foregroundColor(.secondary) }
            }
            Text(clientName).font(.subheadline)
            HStack(spacing: 8) {
                Text(deal.stage.displayName).font(.caption)
                if let nextDueAt = deal.nextDueAt {
                    Label(DisplayFormat.date(nextDueAt), systemImage: "calendar")
                }
            }
            .font(.caption).foregroundColor(.secondary)
        }
    }
}

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

    private var summary: PipelineSummary {
        PipelineSummaryBuilder.summary(from: deals)
    }

    private var openValueText: String? {
        DisplayFormat.amount(summary.totalAmount, currency: summary.primaryCurrency)
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 14) {
                summaryColumn(value: "\(summary.openDealCount)", label: "Open deals")
                Divider()
                summaryColumn(value: openValueText ?? "—", label: "Open value")
            }
            .padding(.vertical, 4)
        }
    }

    private func summaryColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                ForEach(DealStage.allCases, id: \.self) { stage in
                    let stageDeals = DealSorter.sorted(deals.filter { $0.stage == stage })
                    if !stageDeals.isEmpty {
                        Section(stage.displayName) {
                            ForEach(stageDeals) { deal in
                                DealRow(deal: deal)
                            }
                            .onDelete { offsets in
                                offsets.forEach { store.deleteDeal(id: stageDeals[$0].id) }
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
    var onEdit: (() -> Void)? = nil

    private var clientName: String {
        store.client(id: deal.clientID)?.name ?? "Unknown client"
    }

    private var risk: DealRisk { RiskInsights.risk(for: deal) }

    private var riskLabel: (text: String, color: Color)? {
        switch risk.level {
        case .high:
            if deal.stage == .atRisk { return ("At Risk", .red) }
            return ("Stalled \(risk.daysStale)d", .red)
        case .medium:
            return ("Stalled", .orange)
        case .low, .none:
            return nil
        }
    }

    private var amountText: String? {
        DisplayFormat.amount(deal.amount, currency: deal.currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(deal.title).font(.headline)
                Spacer()
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit deal")
                }
                if let amountText { Text(amountText).font(.subheadline).foregroundColor(.secondary) }
            }
            Text(clientName).font(.subheadline)
            HStack(spacing: 8) {
                Text(deal.stage.displayName).font(.caption)
                if let riskLabel {
                    Label(riskLabel.text, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(riskLabel.color)
                }
                if let nextDueAt = deal.nextDueAt {
                    Label(DisplayFormat.date(nextDueAt), systemImage: "calendar")
                }
            }
            .font(.caption).foregroundColor(.secondary)
            if let nextAction = deal.nextAction, !nextAction.isEmpty {
                Label(nextAction, systemImage: "arrow.right.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if !deal.ownerNote.isEmpty {
                Text(deal.ownerNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

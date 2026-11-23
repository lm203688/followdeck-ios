//
//  TodayBoardView.swift
//  FollowDeck
//
//  Today board: pending follow-ups grouped into overdue, today and upcoming.
//  Read-only over the store; quick actions land in a later iteration.
//

import SwiftUI

struct TodayBoardView: View {
    @EnvironmentObject private var store: StoreBridge

    private var stats: DashboardStats {
        DashboardStatsBuilder.stats(from: store.store)
    }

    private var overdue: [FollowUp] {
        store.pendingFollowUps().filter { RiskInsights.bucket(for: $0) == .overdue }
    }

    private var today: [FollowUp] {
        store.pendingFollowUps().filter { RiskInsights.bucket(for: $0) == .today }
    }

    private var upcoming: [FollowUp] {
        store.pendingFollowUps().filter { RiskInsights.bucket(for: $0) == .upcoming }
    }

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                section(title: "Overdue", items: overdue, tint: .red)
                section(title: "Today", items: today, tint: .orange)
                section(title: "Upcoming", items: upcoming, tint: .blue)
            }
            .navigationTitle("Today")
            .overlay {
                if store.pendingFollowUps().isEmpty {
                    ContentUnavailableView(
                        "No follow-ups due",
                        systemImage: "checkmark.circle",
                        description: Text("Add a follow-up and it will show up here.")
                    )
                }
            }
        }
    }

    private var overviewSection: some View {
        Section {
            HStack(spacing: 14) {
                statColumn(value: stats.clientCount, label: "Clients", color: .primary)
                statColumn(value: stats.openDealCount, label: "Open deals", color: .primary)
                Divider()
                statColumn(value: stats.overdueCount, label: "Overdue", color: .red)
                statColumn(value: stats.todayCount, label: "Today", color: .orange)
                statColumn(value: stats.upcomingCount, label: "Upcoming", color: .blue)
            }
            .padding(.vertical, 4)
        }
    }

    private func statColumn(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func section(title: String, items: [FollowUp], tint: Color) -> some View {
        Section(title) {
            if items.isEmpty {
                Text("Nothing here").foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    FollowUpRow(followUp: item, tint: tint)
                }
            }
        }
    }
}

/// Shared row for a follow-up commitment.
struct FollowUpRow: View {
    @EnvironmentObject private var store: StoreBridge
    let followUp: FollowUp
    let tint: Color
    var onEdit: (() -> Void)? = nil

    private var clientName: String {
        store.client(id: followUp.clientID)?.name ?? "Unknown client"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(tint)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(clientName).font(.headline)
                Text(followUp.note).font(.subheadline).lineLimit(2)
                HStack(spacing: 8) {
                    Label(DisplayFormat.dateTime(followUp.dueAt), systemImage: "clock")
                    Text(followUp.channel.displayName)
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit follow-up")
                }
                Button {
                    store.completeFollowUp(id: followUp.id, at: Date())
                } label: {
                    Image(systemName: followUp.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(followUp.status == .done ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(followUp.status == .done ? "Completed" : "Mark as done")
                .disabled(followUp.status == .done)
            }
        }
    }
}

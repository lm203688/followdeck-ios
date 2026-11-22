//
//  FollowUpsView.swift
//  FollowDeck
//
//  Full follow-up list across all statuses. Read-only over the store for now.
//

import SwiftUI

struct FollowUpsView: View {
    @EnvironmentObject private var store: StoreBridge
    @State private var showingAddFollowUp = false

    private var followUps: [FollowUp] { store.allFollowUps() }

    var body: some View {
        NavigationStack {
            List {
                ForEach(followUps) { item in
                    FollowUpRow(followUp: item, tint: color(for: item.status))
                }
                .onDelete { offsets in
                    offsets.forEach { store.deleteFollowUp(id: followUps[$0].id) }
                }
            }
            .navigationTitle("Follow-ups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddFollowUp = true
                    } label: {
                        Label("Add follow-up", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFollowUp) {
                AddFollowUpView()
            }
            .overlay {
                if followUps.isEmpty {
                    ContentUnavailableView(
                        "No follow-ups",
                        systemImage: "list.bullet",
                        description: Text("Commitments you add will appear here.")
                    )
                }
            }
        }
    }

    private func color(for status: FollowUpStatus) -> Color {
        switch status {
        case .pending:  return .blue
        case .done:     return .green
        case .snoozed:  return .gray
        }
    }
}

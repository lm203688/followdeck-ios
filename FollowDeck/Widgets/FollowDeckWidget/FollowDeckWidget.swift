//
//  FollowDeckWidget.swift
//  FollowDeckWidget
//
//  Glanceable home-screen widget. Reads the summary snapshot written to the shared App Group
//  by the main app; no network access and no direct persistence from the extension.
//

import WidgetKit
import SwiftUI

/// Timeline entry carrying the latest local summary.
struct FollowDeckEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Provides entries on demand; the app pushes a timeline reload whenever records change.
struct FollowDeckProvider: TimelineProvider {
    func placeholder(in context: Context) -> FollowDeckEntry {
        FollowDeckEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FollowDeckEntry) -> Void) {
        completion(FollowDeckEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FollowDeckEntry>) -> Void) {
        let entry = FollowDeckEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct FollowDeckWidgetEntryView: View {
    let entry: FollowDeckEntry

    private var snapshot: WidgetSnapshot? { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Follow-ups")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                countBox(label: "Overdue", value: snapshot?.overdueCount ?? 0, color: .red)
                countBox(label: "Today", value: snapshot?.todayCount ?? 0, color: .blue)
                countBox(label: "Upcoming", value: snapshot?.upcomingCount ?? 0, color: .secondary)
            }

            if let titles = snapshot?.topTitles, !titles.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(titles.prefix(2), id: \.self) { title in
                        Text(title)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                }
            } else {
                Text("Nothing pending.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .widgetURL(URL(string: "followdeck://today"))
    }

    private func countBox(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

@main
struct FollowDeckWidget: Widget {
    private let kind = "FollowDeckWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FollowDeckProvider()) { entry in
            FollowDeckWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FollowDeck")
        .description("Pending follow-ups at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

//
//  SettingsView.swift
//  FollowDeck
//
//  Settings / About screen: version info, local-first data explanation, the
//  local JSON export entry, a mailto feedback link (composed by the system
//  mail app; nothing is uploaded automatically) and the privacy posture note.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: StoreBridge
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    private let info = AppInfo.current()

    private var feedbackURL: URL? {
        let device = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        let body = "Device: \(device)\nApp: \(info.versionDisplay)\n\n"
        return FeedbackMail.composeURL(
            to: FeedbackMail.placeholderRecipient,
            subject: "FollowDeck feedback",
            body: body
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    LabeledContent("Version", value: info.versionDisplay)
                }

                Section("Your data") {
                    Text("All clients, follow-ups, deals and interactions are stored only on this device. This build has no account, sync or cloud backup.")
                        .foregroundColor(.secondary)
                    NavigationLink {
                        ExportDataView()
                    } label: {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }
                }

                Section("Subscription") {
                    if subscriptions.isPro {
                        LabeledContent("Plan", value: "FollowDeck Pro")
                    } else {
                        Text("Free plan — up to \(EntitlementPolicy.freeTierClientLimit) clients.")
                            .foregroundColor(.secondary)
                    }
                    Button {
                        subscriptions.restorePurchases()
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                    .disabled(subscriptions.isRestoring)
                    if subscriptions.isRestoring {
                        ProgressView()
                    }
                    if let message = subscriptions.message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Feedback") {
                    Text("Found a problem or have an idea? This opens your mail app with a new message; FollowDeck does not upload any data on its own.")
                        .foregroundColor(.secondary)
                    if let feedbackURL {
                        Link(destination: feedbackURL) {
                            Label("Send feedback", systemImage: "envelope")
                        }
                    }
                }

                Section("Privacy") {
                    Text("FollowDeck includes no advertising or analytics SDK and does not read your contacts' address books automatically. The full privacy policy is linked from the App Store support page.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

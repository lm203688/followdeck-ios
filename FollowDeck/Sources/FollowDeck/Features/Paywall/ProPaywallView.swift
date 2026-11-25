//
//  ProPaywallView.swift
//  FollowDeck
//
//  SwiftUI paywall for FollowDeck Pro. It consumes the ready-to-display
//  `PaywallPresentation` assembled by the SubscriptionManager and forwards
//  purchase / restore requests to the subscription service. All pricing,
//  period, trial and ordering copy stays in the deterministic catalog layer;
//  this view only lays out the plans, the selected option and the in-flight
//  purchase / restore state. No card data is handled in the app.
//

import SwiftUI

struct ProPaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// The plan the user currently has selected on the paywall.
    @State private var selectedPlanID: String?

    init(initialPlanID: String? = nil) {
        _selectedPlanID = State(initialValue: initialPlanID)
    }

    /// Public privacy policy linked from the paywall footnote.
    private static let privacyURL = URL(
        string: "https://lm203688.github.io/followdeck-site/privacy.html"
    )!

    private var presentation: PaywallPresentation { subscriptions.presentation }

    private var selectedPlan: PaywallPlan? {
        if let id = selectedPlanID,
           let plan = presentation.plans.first(where: { $0.id == id }) {
            return plan
        }
        // Fall back to the recommended plan (or first) when products load
        // after the view first appears, so the CTA never stays disabled.
        return presentation.recommended ?? presentation.plans.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if subscriptions.isPro {
                        proActiveCard
                    } else {
                        headerSection
                        featureSection
                        if presentation.hasPlans {
                            planPicker
                        } else {
                            unavailableCard
                        }
                        purchaseSection
                    }
                    restoreSection
                    messageSection
                    legalSection
                }
                .padding()
            }
            .navigationTitle("FollowDeck Pro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear { selectDefaultPlan() }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlock FollowDeck Pro")
                .font(.title2.bold())
            Text("Remove the 20-client cap and keep an unlimited roster of clients.")
                .foregroundColor(.secondary)
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(presentation.features, id: \.self) { feature in
                Label(feature, systemImage: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }

    @ViewBuilder
    private var planPicker: some View {
        VStack(spacing: 12) {
            ForEach(presentation.plans) { plan in
                planCard(for: plan)
            }
        }
    }

    private func planCard(for plan: PaywallPlan) -> some View {
        let isSelected = plan.id == selectedPlan?.id
        return Button {
            selectedPlanID = plan.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.headline)
                        if plan.isRecommended {
                            Text("Best value")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 6) {
                        Text(plan.priceDisplay)
                        Text("·")
                        Text(plan.period)
                    }
                    .foregroundColor(.secondary)
                    if let trialCopy = plan.trialCopy {
                        Text(trialCopy)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Plans unavailable", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("Pro plans could not be loaded right now. Check your connection and try again, or restore a previous purchase below.")
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var purchaseSection: some View {
        VStack(spacing: 8) {
            Button {
                guard let plan = selectedPlan else { return }
                subscriptions.purchase(productID: plan.id)
            } label: {
                HStack {
                    if subscriptions.isPurchasing {
                        ProgressView()
                    } else {
                        Text(selectedPlan?.ctaTitle ?? "Subscribe")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPlan == nil || subscriptions.isPurchasing)

            if let plan = selectedPlan {
                Text(plan.priceDisplay + " · " + plan.period)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var restoreSection: some View {
        HStack {
            Button {
                subscriptions.restorePurchases()
            } label: {
                HStack(spacing: 6) {
                    if subscriptions.isRestoring {
                        ProgressView()
                    }
                    Text("Restore Purchases")
                }
            }
            .disabled(subscriptions.isRestoring)
            Spacer()
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let message = subscriptions.message, !message.isEmpty {
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subscriptions renew automatically at the end of each period unless cancelled at least 24 hours before renewal. You can manage or cancel anytime in your App Store account settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
            Link("Privacy Policy", destination: Self.privacyURL)
                .font(.caption2)
        }
    }

    private var proActiveCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            Text("You're on FollowDeck Pro")
                .font(.headline)
            Text("An unlimited client roster is active on this device.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers

    /// Default to the recommended best-value plan; fall back to the first plan.
    private func selectDefaultPlan() {
        // Products load asynchronously. Before the catalog arrives, keep any explicit
        // preselection (used by screenshot launches) instead of falling back to the
        // recommended plan and losing it once products resolve.
        guard !presentation.plans.isEmpty else { return }
        guard selectedPlanID == nil || !presentation.plans.contains(where: { $0.id == selectedPlanID }) else { return }
        selectedPlanID = presentation.recommended?.id ?? presentation.plans.first?.id
    }
}

#Preview {
    ProPaywallView()
        .environmentObject(SubscriptionManager())
}

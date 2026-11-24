//
//  SubscriptionManager.swift
//  FollowDeck
//
//  Observable subscription state for SwiftUI. It owns the SubscriptionService,
//  publishes the resolved entitlement, and mirrors transaction updates into the
//  local tier. Offline, expired or unverified state falls back to the free tier.
//

import Foundation
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    /// Current access tier for this install.
    @Published var entitlement: Entitlement = .free
    /// Pro products available in the store.
    @Published var products: [DisplayProduct] = []
    /// Whether a restore-purchases pass is in flight.
    @Published var isRestoring = false
    /// Whether a purchase pass is in flight.
    @Published var isPurchasing = false
    /// Short user-facing status message (restore / errors).
    @Published var message: String?

    private let service: SubscriptionServiceProtocol
    private var updateTask: Task<Void, Never>?

    init(service: SubscriptionServiceProtocol = StoreKitSubscriptionService()) {
        self.service = service
    }

    var isPro: Bool { entitlement == .pro }

    /// Load the current entitlement and begin listening for transaction updates.
    func start() {
        refresh()
        updateTask = Task { [weak self] in
            guard let self else { return }
            for await active in self.service.updates() {
                self.apply(activeProductIDs: active)
            }
        }
    }

    /// Re-read the active entitlements and available products off the main flow.
    func refresh() {
        Task { await reload() }
    }

    func reload() async {
        let active = await service.activeProductIDs()
        apply(activeProductIDs: active)
        do {
            products = try await service.loadProducts()
        } catch {
            // Product listing is non-essential until the Pro batch; keep prior state.
        }
    }

    /// Restore purchases from the App Store and update the local entitlement.
    func restorePurchases() {
        Task { await performRestore() }
    }

    /// Async restore execution, exposed so tests can await the state flow directly.
    func performRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            let active = try await service.restorePurchases()
            apply(activeProductIDs: active)
            message = active.isEmpty ? "No active subscription found." : "Purchases restored."
        } catch {
            message = "Could not restore purchases. Please try again."
        }
    }

    /// Purchase the Pro product with the given ID and update the local entitlement.
    /// The actual StoreKit sheet is presented by the service layer; the manager only
    /// forwards the request, tracks the in-flight state and mirrors the result.
    func purchase(productID: String) {
        Task { await performPurchase(productID: productID) }
    }

    /// Async purchase execution, exposed so tests can await the state flow directly.
    func performPurchase(productID: String) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let active = try await service.purchase(productID: productID)
            apply(activeProductIDs: active)
            message = active.isEmpty ? "Purchase completed." : "Welcome to FollowDeck Pro."
        } catch SubscriptionError.userCancelled {
            message = "Purchase cancelled."
        } catch {
            message = "Could not complete purchase. Please try again."
        }
    }

    /// Whether a new client may be added under the current entitlement.
    func canAddClient(currentCount: Int) -> Bool {
        EntitlementPolicy.canAddClient(currentClientCount: currentCount, entitlement: entitlement)
    }

    private func apply(activeProductIDs: Set<String>) {
        entitlement = EntitlementPolicy.entitlement(activeProductIDs: activeProductIDs)
    }

    deinit { updateTask?.cancel() }
}

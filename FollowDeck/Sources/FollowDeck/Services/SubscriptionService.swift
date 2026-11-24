//
//  SubscriptionService.swift
//  FollowDeck
//
//  StoreKit 2 subscription layer. The protocol keeps the UI and the entitlement
//  policy decoupled from Apple's StoreKit types; `StoreKitSubscriptionService` is
//  the production implementation backed by StoreKit 2. Purchase, restore and
//  transaction updates flow through this service; the app never handles card data.
//

import Foundation
import StoreKit

/// A store-facing subscription product, decoupled from the StoreKit Product type.
struct DisplayProduct: Identifiable, Equatable {
    /// The App Store Connect product ID.
    let id: String
    /// Localized display name.
    let name: String
    /// Localized price string (e.g. "$4.99").
    let priceDisplay: String
    /// Subscription period (e.g. "1 month", "1 year").
    let period: String
}

/// Abstraction over the StoreKit subscription backend, injectable for tests.
protocol SubscriptionServiceProtocol: AnyObject {
    /// Load the Pro products that are available in the store.
    func loadProducts() async throws -> [DisplayProduct]

    /// Purchase the product with the given ID; returns the active Pro product
    /// identifier set after the transaction finishes.
    func purchase(productID: String) async throws -> Set<String>

    /// Sync with the App Store and return the restored active Pro product set.
    func restorePurchases() async throws -> Set<String>

    /// The Pro product identifiers with a currently valid, non-revoked entitlement.
    func activeProductIDs() async -> Set<String>

    /// A stream that emits the active Pro product set whenever transactions update.
    func updates() -> AsyncStream<Set<String>>
}

/// Production StoreKit 2 implementation.
final class StoreKitSubscriptionService: SubscriptionServiceProtocol {

    func loadProducts() async throws -> [DisplayProduct] {
        let products = try await Product.products(for: ProductIDs.all)
        return products
            .sorted { $0.id < $1.id }
            .map { product in
                DisplayProduct(
                    id: product.id,
                    name: product.displayName,
                    priceDisplay: product.displayPrice,
                    period: Self.periodDescription(of: product.subscription?.period)
                )
            }
    }

    func purchase(productID: String) async throws -> Set<String> {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            throw SubscriptionError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard let transaction = Self.verifiedTransaction(verification) else {
                throw SubscriptionError.unverifiedTransaction
            }
            await transaction.finish()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unverifiedTransaction
        }

        return await activeProductIDs()
    }

    func restorePurchases() async throws -> Set<String> {
        await AppStore.sync()
        return await activeProductIDs()
    }

    func activeProductIDs() async -> Set<String> {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = Self.verifiedTransaction(result),
                  Self.isActive(transaction) else { continue }
            if ProductIDs.isProProduct(transaction.productID) {
                active.insert(transaction.productID)
            }
        }
        return active
    }

    func updates() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                for await result in Transaction.updates {
                    guard Self.verifiedTransaction(result) != nil else { continue }
                    let active = await self.activeProductIDs()
                    continuation.yield(active)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private helpers

    private static func verifiedTransaction(_ result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction): return transaction
        case .unverified: return nil
        }
    }

    private static func isActive(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil, !transaction.isUpgraded else { return false }
        if let expirationDate = transaction.expirationDate {
            return expirationDate > Date()
        }
        return true
    }

    private static func periodDescription(of period: Product.SubscriptionPeriod?) -> String {
        guard let period else { return "" }
        switch (period.unit, period.value) {
        case (.month, 1): return "1 month"
        case (.year, 1):  return "1 year"
        case (.month, let v): return "\(v) months"
        case (.year, let v):  return "\(v) years"
        default: return ""
        }
    }
}

/// Errors surfaced from the subscription flow.
enum SubscriptionError: Error, Equatable {
    case productNotFound
    case unverifiedTransaction
    case userCancelled
    case pending
}

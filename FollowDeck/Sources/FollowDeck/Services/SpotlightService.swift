//
//  SpotlightService.swift
//  FollowDeck
//
//  System Spotlight indexing for clients and deals. The protocol keeps the bridge decoupled
//  from CoreSpotlight so indexing can be faked in unit tests. Indexing is local-only; no
//  record leaves the device.
//

import Foundation
import CoreSpotlight
import MobileCoreServices

protocol SpotlightIndexerProtocol: AnyObject {
    /// Index (or refresh) a client record so it appears in system search.
    func index(client: Client)
    /// Index (or refresh) a deal record so it appears in system search.
    func index(deal: Deal)
    /// Remove a single indexed record by its record UUID.
    func removeRecord(id: UUID)
    /// Clear all indexed records.
    func removeAll()
}

/// CoreSpotlight-backed implementation. Uses the default on-device index.
final class SpotlightIndexer: SpotlightIndexerProtocol {
    static let shared = SpotlightIndexer()

    private let index: CSSearchableIndex

    init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    func index(client: Client) {
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeContact as String)
        attributes.title = client.name
        attributes.contentDescription = [client.email, client.phone].compactMap { $0 }.joined(separator: " · ")
        attributes.keywords = client.tags

        let item = CSSearchableItem(
            uniqueIdentifier: client.id.uuidString,
            domainIdentifier: "followdeck.client",
            attributeSet: attributes
        )
        index.indexSearchableItems([item])
    }

    func index(deal: Deal) {
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
        attributes.title = deal.title
        attributes.contentDescription = deal.stage.displayName

        let item = CSSearchableItem(
            uniqueIdentifier: deal.id.uuidString,
            domainIdentifier: "followdeck.deal",
            attributeSet: attributes
        )
        index.indexSearchableItems([item])
    }

    func removeRecord(id: UUID) {
        index.deleteSearchableItems(withIdentifiers: [id.uuidString])
    }

    func removeAll() {
        index.deleteAllSearchableItems()
    }
}

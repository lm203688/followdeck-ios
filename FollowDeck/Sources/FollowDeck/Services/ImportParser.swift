//
//  ImportParser.swift
//  FollowDeck
//
//  Local-only restore validation. This is the portable JSON-to-model layer that
//  pairs with the local export: it decodes a previously written snapshot, checks
//  foreign-key consistency, drops orphaned records and de-duplicates repeated IDs.
//  No network call and no persistence write happen here; the store restore and the
//  file-picker / share-import UI are wired separately.
//

import Foundation

/// Why a backup could not be restored. Cases distinguish malformed JSON, a schema
/// that does not match this app's snapshot, and an empty client list (which must
/// not be used to wipe an existing library).
enum ImportError: Error, Equatable {
    case invalidJSON
    case incompatibleSchema
    case emptySnapshot
}

/// A validated restore plan: the records that survived validation, plus which
/// orphaned / duplicate records were excluded so the UI can report them.
struct ImportResult: Equatable {
    var clients: [Client]
    var deals: [Deal]
    var followUps: [FollowUp]
    var interactions: [Interaction]
    var droppedDealIDs: [UUID]
    var droppedFollowUpIDs: [UUID]
    var droppedInteractionIDs: [UUID]
    var duplicateClientIDs: [UUID]
}

enum ImportParser {

    /// Decode and validate an exported JSON snapshot for restore.
    /// - Throws: `ImportError.invalidJSON` when the data is not legal JSON,
    ///   `ImportError.incompatibleSchema` when it does not match the snapshot model,
    ///   or `ImportError.emptySnapshot` when it carries no clients.
    static func parse(data: Data) throws -> ImportResult {
        // 1. Reject data that is not JSON at all.
        guard (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
            throw ImportError.invalidJSON
        }

        // 2. Decode into the snapshot model; any decoding mismatch is a schema error.
        let snapshot: ExportSnapshot
        do {
            snapshot = try ExportService.snapshot(from: data)
        } catch {
            throw ImportError.incompatibleSchema
        }

        // 3. An empty client list would wipe the library on restore; refuse it.
        guard !snapshot.clients.isEmpty else {
            throw ImportError.emptySnapshot
        }

        // 4. De-duplicate clients by id, keeping the first occurrence.
        var seenClientIDs = Set<UUID>()
        var clients: [Client] = []
        var duplicateClientIDs: [UUID] = []
        for client in snapshot.clients {
            if seenClientIDs.insert(client.id).inserted {
                clients.append(client)
            } else {
                duplicateClientIDs.append(client.id)
            }
        }
        let clientIDs = Set(clients.map { $0.id })

        // 5. Keep only deals whose client still exists; de-duplicate deal ids.
        var seenDealIDs = Set<UUID>()
        var deals: [Deal] = []
        var droppedDealIDs: [UUID] = []
        for deal in snapshot.deals {
            guard clientIDs.contains(deal.clientID) else {
                droppedDealIDs.append(deal.id)
                continue
            }
            if seenDealIDs.insert(deal.id).inserted {
                deals.append(deal)
            }
        }
        let dealIDs = Set(deals.map { $0.id })

        // 6. Keep follow-ups whose client exists and whose linked deal (if any) exists.
        var followUps: [FollowUp] = []
        var droppedFollowUpIDs: [UUID] = []
        for followUp in snapshot.followUps {
            guard clientIDs.contains(followUp.clientID) else {
                droppedFollowUpIDs.append(followUp.id)
                continue
            }
            if let dealID = followUp.dealID, !dealIDs.contains(dealID) {
                droppedFollowUpIDs.append(followUp.id)
                continue
            }
            followUps.append(followUp)
        }

        // 7. Keep interactions whose client exists and whose linked deal (if any) exists.
        var interactions: [Interaction] = []
        var droppedInteractionIDs: [UUID] = []
        for interaction in snapshot.interactions {
            guard clientIDs.contains(interaction.clientID) else {
                droppedInteractionIDs.append(interaction.id)
                continue
            }
            if let dealID = interaction.dealID, !dealIDs.contains(dealID) {
                droppedInteractionIDs.append(interaction.id)
                continue
            }
            interactions.append(interaction)
        }

        return ImportResult(
            clients: clients,
            deals: deals,
            followUps: followUps,
            interactions: interactions,
            droppedDealIDs: droppedDealIDs,
            droppedFollowUpIDs: droppedFollowUpIDs,
            droppedInteractionIDs: droppedInteractionIDs,
            duplicateClientIDs: duplicateClientIDs
        )
    }
}

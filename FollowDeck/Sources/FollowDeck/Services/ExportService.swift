//
//  ExportService.swift
//  FollowDeck
//
//  Local-only export serialization. This is the portable model-to-JSON layer behind the
//  planned Pro export feature; it performs no network call and writes nothing outside the
//  device. The share/export UI and any paywall are wired separately.
//

import Foundation

/// A point-in-time copy of all local records, Codable so it can be serialized to JSON.
struct ExportSnapshot: Codable, Equatable {
    let clients: [Client]
    let deals: [Deal]
    let followUps: [FollowUp]
    let interactions: [Interaction]
    let exportedAt: Date
}

enum ExportService {
    static func snapshot(clients: [Client],
                         deals: [Deal],
                         followUps: [FollowUp],
                         interactions: [Interaction],
                         exportedAt: Date = Date()) -> ExportSnapshot {
        ExportSnapshot(
            clients: clients,
            deals: deals,
            followUps: followUps,
            interactions: interactions,
            exportedAt: exportedAt
        )
    }

    /// Encode the snapshot to pretty-printed UTF-8 JSON data.
    static func jsonData(for snapshot: ExportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    /// Decode JSON data back into a snapshot (used to validate the round trip).
    static func snapshot(from data: Data) throws -> ExportSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportSnapshot.self, from: data)
    }
}

/// A ready-to-share local export: a suggested file name plus encoded JSON data.
struct ExportedFile: Equatable {
    let fileName: String
    let data: Data
}

/// Aggregates every local record from the store into an export snapshot and builds the
/// shareable file. Pure Foundation logic; the share sheet / UI lives in the feature layer.
enum ExportBuilder {
    static func snapshot(from store: StoreProtocol) -> ExportSnapshot {
        ExportService.snapshot(
            clients: store.clients(),
            deals: store.allDeals(),
            followUps: store.allFollowUps(),
            interactions: store.allInteractions()
        )
    }

    static func makeFile(from store: StoreProtocol, date: Date = Date()) throws -> ExportedFile {
        let snapshot = snapshot(from: store)
        let data = try ExportService.jsonData(for: snapshot)
        return ExportedFile(fileName: "followdeck-export-\(stamp(date)).json", data: data)
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

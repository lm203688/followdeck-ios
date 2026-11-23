//
//  CsvExport.swift
//  FollowDeck
//
//  Local-only CSV export. Portable Foundation logic that turns an export snapshot into
//  spreadsheet-ready text for contacts and follow-ups. No network call, account or
//  paywall; CSV destinations stay on device until the user shares the file.
//

import Foundation

/// Builds CSV text from an `ExportSnapshot`. Contacts and follow-ups are emitted as
/// separate tables so each can be opened independently in a spreadsheet.
enum CsvBuilder {

    static let clientHeader = "Name,Phone,Email,Tags,Status,Last contacted,Created"
    static let followUpHeader = "Note,Type,Status,Channel,Due,Completed,Created,Client ID"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// CSV rows for every client in the snapshot.
    static func clientsCSV(from snapshot: ExportSnapshot) -> String {
        var lines = [clientHeader]
        for client in snapshot.clients {
            let tags = client.tags.joined(separator: "; ")
            lines.append(row([
                client.name,
                client.phone,
                client.email,
                tags,
                client.status,
                dateString(client.lastContactedAt),
                dateString(client.createdAt)
            ]))
        }
        return lines.joined(separator: "\n")
    }

    /// CSV rows for every follow-up in the snapshot.
    static func followUpsCSV(from snapshot: ExportSnapshot) -> String {
        var lines = [followUpHeader]
        for followUp in snapshot.followUps {
            lines.append(row([
                followUp.note,
                followUp.type.rawValue,
                followUp.status.rawValue,
                followUp.channel.rawValue,
                dateString(followUp.dueAt),
                dateString(followUp.completedAt),
                dateString(followUp.createdAt),
                followUp.clientID.uuidString
            ]))
        }
        return lines.joined(separator: "\n")
    }

    private static func row(_ fields: [String?]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// RFC 4180 escaping: wrap in double quotes when the field contains a comma,
    /// quote, or line break; double embedded quotes. Empty / nil fields become an
    /// empty column.
    private static func escape(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        if value.contains(",") || value.contains("\"") ||
            value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func dateString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return dateFormatter.string(from: date)
    }
}

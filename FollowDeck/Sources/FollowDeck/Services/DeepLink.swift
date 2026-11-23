//
//  DeepLink.swift
//  FollowDeck
//
//  Pure URL → tab mapping for widget and notification deep links. No SwiftUI here so the
//  routing rules can be unit-tested off-device.
//

import Foundation

enum DeepLinkTarget: Hashable {
    case today
    case pipeline
    case clients
    case followUps
}

enum DeepLinkParser {
    static let scheme = "followdeck"

    static func target(for url: URL) -> DeepLinkTarget {
        guard url.scheme == scheme else { return .today }
        switch url.host {
        case "pipeline": return .pipeline
        case "clients": return .clients
        case "followups": return .followUps
        default: return .today
        }
    }
}

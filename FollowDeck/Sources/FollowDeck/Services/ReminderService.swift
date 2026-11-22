//
//  ReminderService.swift
//  FollowDeck
//
//  Local notification scheduling for follow-ups. Wires to UNUserNotificationCenter
//  in the Xcode project on macOS; deep links open the related deal/client.
//

import Foundation

protocol ReminderServiceProtocol: AnyObject {
    func requestAuthorization() async throws
    func schedule(_ followUp: FollowUp)
    func cancel(id: UUID)
    func reschedule(_ followUp: FollowUp)
}

final class ReminderService: ReminderServiceProtocol {
    func requestAuthorization() async throws {
        // TODO(macOS): UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge])
    }

    func schedule(_ followUp: FollowUp) {
        // TODO(macOS): build UNCalendarNotificationTrigger, identifier = followUp.id.uuidString,
        // deep-link userInfo ["dealID": ..., "clientID": ...].
    }

    func cancel(id: UUID) {
        // TODO(macOS): removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func reschedule(_ followUp: FollowUp) {
        cancel(id: followUp.id)
        schedule(followUp)
    }
}

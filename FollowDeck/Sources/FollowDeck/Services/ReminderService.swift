//
//  ReminderService.swift
//  FollowDeck
//
//  Local notification scheduling for follow-ups. Uses UNUserNotificationCenter;
//  notifications carry deep-link userInfo so a tap can open the related record.
//  Scheduling is local-only — no push provider, no server.
//

import Foundation
import UserNotifications

protocol ReminderServiceProtocol: AnyObject {
    func requestAuthorization() async throws
    func schedule(_ followUp: FollowUp)
    func cancel(id: UUID)
    func reschedule(_ followUp: FollowUp)
}

final class ReminderService: ReminderServiceProtocol {
    static let shared = ReminderService()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ followUp: FollowUp) {
        // Only pending follow-ups with a future due date are scheduled.
        guard followUp.status == .pending, followUp.dueAt > Date() else {
            cancel(id: followUp.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Follow-up reminder"
        content.body = followUp.note
        content.userInfo = [
            "followUpID": followUp.id.uuidString,
            "clientID": followUp.clientID.uuidString
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: followUp.dueAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: followUp.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    func reschedule(_ followUp: FollowUp) {
        cancel(id: followUp.id)
        schedule(followUp)
    }
}

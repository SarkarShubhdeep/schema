//
//  NotificationService.swift
//  Schema
//

import Foundation

protocol NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func scheduleReminder(for task: SchemaTask) async throws
    func cancelReminder(for task: SchemaTask)
}

#if os(macOS)
import UserNotifications

final class NotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleReminder(for task: SchemaTask) async throws {
        guard let reminderTime = task.reminderTime, reminderTime > Date() else { return }

        cancelReminder(for: task)

        let content = UNMutableNotificationContent()
        content.title = task.title
        if let description = task.displayDescription {
            content.body = description
        }
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: task),
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelReminder(for task: SchemaTask) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID(for: task)])
    }

    private func notificationID(for task: SchemaTask) -> String {
        "schema.task.\(task.id.uuidString)"
    }
}
#else
final class NotificationService: NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool { false }
    func scheduleReminder(for task: SchemaTask) async throws {}
    func cancelReminder(for task: SchemaTask) {}
}
#endif

//
//  NotificationService.swift
//  Schema
//

import Foundation

@MainActor
protocol NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func scheduleReminder(for task: SchemaTask) async throws
    func cancelReminder(for task: SchemaTask)
    func rescheduleAllReminders(for tasks: [SchemaTask]) async
}

#if os(macOS)
import UserNotifications

@MainActor
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
        } else if let listTitle = task.list?.title {
            content.body = listTitle
        }
        content.sound = .default
        content.userInfo = [
            NotificationUserInfoKey.taskID: task.id.uuidString,
            NotificationUserInfoKey.listID: task.list?.id.uuidString as Any
        ]

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
        center.removeDeliveredNotifications(withIdentifiers: [notificationID(for: task)])
    }

    func rescheduleAllReminders(for tasks: [SchemaTask]) async {
        let pendingTasks = tasks.filter { task in
            guard let reminderTime = task.reminderTime else { return false }
            return reminderTime > Date() && !task.isCompleted
        }

        guard !pendingTasks.isEmpty else { return }

        do {
            let authorized = try await requestAuthorization()
            guard authorized else { return }

            for task in pendingTasks {
                try await scheduleReminder(for: task)
            }
        } catch {
            assertionFailure("Failed to reschedule reminders: \(error)")
        }
    }

    private func notificationID(for task: SchemaTask) -> String {
        "schema.task.\(task.id.uuidString)"
    }
}
#else
@MainActor
final class NotificationService: NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool { false }
    func scheduleReminder(for task: SchemaTask) async throws {}
    func cancelReminder(for task: SchemaTask) {}
    func rescheduleAllReminders(for tasks: [SchemaTask]) async {}
}
#endif

enum NotificationUserInfoKey {
    static let taskID = "taskID"
    static let listID = "listID"
}

enum NotificationNames {
    static let taskReminderOpened = Notification.Name("schema.taskReminderOpened")
}

extension Notification {
    var openedTaskID: UUID? {
        guard let rawValue = userInfo?[NotificationUserInfoKey.taskID] as? String else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    var openedListID: UUID? {
        guard let rawValue = userInfo?[NotificationUserInfoKey.listID] as? String else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }
}

#if os(macOS)
@MainActor
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let taskID = response.notification.request.content.userInfo[NotificationUserInfoKey.taskID] as? String
        let listID = response.notification.request.content.userInfo[NotificationUserInfoKey.listID] as? String

        await MainActor.run {
            var payload: [String: String] = [:]
            if let taskID { payload[NotificationUserInfoKey.taskID] = taskID }
            if let listID { payload[NotificationUserInfoKey.listID] = listID }

            NotificationCenter.default.post(
                name: NotificationNames.taskReminderOpened,
                object: nil,
                userInfo: payload
            )
        }
    }
}
#endif

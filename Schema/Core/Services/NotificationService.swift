//
//  NotificationService.swift
//  Schema
//

import Foundation

@MainActor
protocol NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func scheduleReminder(for task: SchemaTask) async throws
    func cancelReminder(for task: SchemaTask)
    func rescheduleAllReminders(for tasks: [SchemaTask]) async
    func fetchPendingReminders() async -> [SchemaNotificationItem]
}

enum NotificationAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

#if os(macOS)
import UserNotifications

@MainActor
final class NotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .notDetermined
        }
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

    func fetchPendingReminders() async -> [SchemaNotificationItem] {
        let requests = await center.pendingNotificationRequests()
        return requests
            .compactMap { request -> SchemaNotificationItem? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let fireDate = trigger.nextTriggerDate(),
                      fireDate > Date() else {
                    return nil
                }

                let userInfo = request.content.userInfo
                let taskID = (userInfo[NotificationUserInfoKey.taskID] as? String).flatMap(UUID.init(uuidString:))
                let listID = (userInfo[NotificationUserInfoKey.listID] as? String).flatMap(UUID.init(uuidString:))

                return SchemaNotificationItem(
                    id: request.identifier,
                    taskID: taskID,
                    listID: listID,
                    title: request.content.title,
                    subtitle: request.content.body.isEmpty ? nil : request.content.body,
                    fireDate: fireDate
                )
            }
            .sorted { $0.fireDate < $1.fireDate }
    }

    private func notificationID(for task: SchemaTask) -> String {
        "schema.task.\(task.id.uuidString)"
    }
}
#else
@MainActor
final class NotificationService: NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool { false }
    func authorizationStatus() async -> NotificationAuthorizationStatus { .denied }
    func scheduleReminder(for task: SchemaTask) async throws {}
    func cancelReminder(for task: SchemaTask) {}
    func rescheduleAllReminders(for tasks: [SchemaTask]) async {}
    func fetchPendingReminders() async -> [SchemaNotificationItem] { [] }
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
        let taskID = response.notification.request.content.userInfo["taskID"] as? String
        let listID = response.notification.request.content.userInfo["listID"] as? String

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

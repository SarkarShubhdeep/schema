//
//  TaskViewModel.swift
//  Schema
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class TaskViewModel {
    private let modelContext: ModelContext
    private let notificationService: any NotificationServiceProtocol

    var quickEntryText = ""

    init(
        modelContext: ModelContext,
        notificationService: any NotificationServiceProtocol
    ) {
        self.modelContext = modelContext
        self.notificationService = notificationService
    }

    func tasks(for list: SchemaList?, from allTasks: [SchemaTask]) -> [SchemaTask] {
        guard let list else { return [] }

        if list.isEverythingList {
            return allTasks.sorted { $0.createdAt < $1.createdAt }
        }

        return allTasks
            .filter { $0.list?.id == list.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func incompleteTasks(for list: SchemaList?, from allTasks: [SchemaTask]) -> [SchemaTask] {
        tasks(for: list, from: allTasks).filter { !$0.isCompleted }
    }

    func completedTasks(for list: SchemaList?, from allTasks: [SchemaTask]) -> [SchemaTask] {
        tasks(for: list, from: allTasks).filter(\.isCompleted)
    }

    @discardableResult
    func addTask(to list: SchemaList?, title: String) -> SchemaTask? {
        guard let list else { return nil }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let targetList = list.isEverythingList ? defaultWritableList() : list
        guard let targetList else { return nil }

        let task = SchemaTask(title: trimmed, list: targetList)
        modelContext.insert(task)
        save()
        quickEntryText = ""
        return task
    }

    func toggleCompletion(_ task: SchemaTask) {
        task.isCompleted.toggle()
        save()

        if task.isCompleted {
            notificationService.cancelReminder(for: task)
        }
    }

    func deleteTask(_ task: SchemaTask) {
        notificationService.cancelReminder(for: task)
        modelContext.delete(task)
        save()
    }

    func updateTitle(_ task: SchemaTask, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.title = trimmed
        save()
    }

    func updateDescription(_ task: SchemaTask, description: String?) {
        let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskDescription = trimmed?.isEmpty == true ? nil : trimmed
        save()
    }

    func setReminder(_ task: SchemaTask, at date: Date?) async {
        task.reminderTime = date
        save()

        if let date, date > Date() {
            do {
                let authorized = try await notificationService.requestAuthorization()
                guard authorized else { return }
                try await notificationService.scheduleReminder(for: task)
            } catch {
                assertionFailure("Failed to schedule reminder: \(error)")
            }
        } else {
            notificationService.cancelReminder(for: task)
        }
    }

    private func defaultWritableList() -> SchemaList? {
        var descriptor = FetchDescriptor<SchemaList>(
            predicate: #Predicate<SchemaList> { list in
                list.title != "Everything"
            },
            sortBy: [SortDescriptor(\.order)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save tasks: \(error)")
        }
    }
}

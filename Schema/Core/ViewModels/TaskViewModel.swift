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

    func tasks(
        for list: SchemaList?,
        from allTasks: [SchemaTask],
        sortOption: TaskSortOption = .manual,
        filterOption: TaskFilterOption = .all
    ) -> [SchemaTask] {
        guard let list else { return [] }

        var result: [SchemaTask]
        if list.isEverythingList {
            result = allTasks
        } else {
            result = allTasks.filter { $0.list?.id == list.id }
        }

        result = applyFilter(result, option: filterOption)
        return applySort(result, option: sortOption)
    }

    func incompleteTasks(
        for list: SchemaList?,
        from allTasks: [SchemaTask],
        sortOption: TaskSortOption = .manual,
        filterOption: TaskFilterOption = .all
    ) -> [SchemaTask] {
        tasks(for: list, from: allTasks, sortOption: sortOption, filterOption: filterOption)
            .filter { !$0.isCompleted }
    }

    func completedTasks(
        for list: SchemaList?,
        from allTasks: [SchemaTask],
        sortOption: TaskSortOption = .manual,
        filterOption: TaskFilterOption = .all
    ) -> [SchemaTask] {
        tasks(for: list, from: allTasks, sortOption: sortOption, filterOption: filterOption)
            .filter(\.isCompleted)
    }

    @discardableResult
    func addTask(
        to list: SchemaList?,
        title: String,
        defaultWritableListID: UUID? = nil,
        lists: [SchemaList] = []
    ) -> SchemaTask? {
        guard let list else { return nil }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let targetList: SchemaList?
        if list.isEverythingList {
            if let defaultWritableListID,
               let preferred = lists.first(where: { $0.id == defaultWritableListID && !$0.isEverythingList }) {
                targetList = preferred
            } else {
                targetList = defaultWritableList(from: lists)
            }
        } else {
            targetList = list
        }

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

    private func defaultWritableList(from lists: [SchemaList]) -> SchemaList? {
        lists.first(where: { !$0.isEverythingList })
    }

    private func applyFilter(_ tasks: [SchemaTask], option: TaskFilterOption) -> [SchemaTask] {
        switch option {
        case .all:
            return tasks
        case .withReminder:
            return tasks.filter { $0.reminderTime != nil }
        case .withoutReminder:
            return tasks.filter { $0.reminderTime == nil }
        }
    }

    private func applySort(_ tasks: [SchemaTask], option: TaskSortOption) -> [SchemaTask] {
        switch option {
        case .manual:
            return tasks.sorted { $0.createdAt < $1.createdAt }
        case .createdAt:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .reminderTime:
            return tasks.sorted { lhs, rhs in
                switch (lhs.reminderTime, rhs.reminderTime) {
                case let (left?, right?):
                    return left < right
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (nil, nil):
                    return lhs.createdAt < rhs.createdAt
                }
            }
        case .alphabetical:
            return tasks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save tasks: \(error)")
        }
    }
}

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
    private var undoStack: [TaskUndoAction] = []
    private let maxUndoCount = 30

    var quickEntryText = ""
    var canUndo: Bool { !undoStack.isEmpty }

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
        let effectiveSort = RoutineSequenceOrdering.requiresManualSort(for: list, in: allTasks)
            ? .manual
            : sortOption
        return applySort(result, option: effectiveSort)
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
        lists: [SchemaList] = [],
        allTasks: [SchemaTask] = [],
        reminderTime: Date? = nil,
        recordUndo: Bool = true
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

        let task = SchemaTask(title: trimmed, list: targetList, reminderTime: reminderTime)
        
        let listTasks = allTasks.filter { $0.list?.id == targetList.id }
        let maxIndex = listTasks.map(\.manualSortIndex).max() ?? 0
        task.manualSortIndex = maxIndex + 1
        
        modelContext.insert(task)
        save()
        quickEntryText = ""

        if recordUndo {
            pushUndo(.addedTask(task.id))
        }

        if reminderTime != nil, !task.isCompleted {
            Task { await setReminder(task, at: reminderTime) }
        }

        return task
    }

    func moveTask(_ task: SchemaTask, to list: SchemaList, allTasks: [SchemaTask]) {
        guard !list.isEverythingList, task.list?.id != list.id else { return }

        task.list = list

        let listTasks = allTasks.filter { $0.list?.id == list.id && $0.id != task.id }
        let maxIndex = listTasks.map(\.manualSortIndex).max() ?? 0
        task.manualSortIndex = maxIndex + 1

        save()
    }

    func isSequenceBlocked(_ task: SchemaTask, in allTasks: [SchemaTask]) -> Bool {
        RoutineSequenceOrdering.isBlocked(task, in: allTasks)
    }

    func canMoveTask(_ task: SchemaTask, in tasks: [SchemaTask]) -> Bool {
        RoutineSequenceOrdering.canMoveIndividually(task, in: tasks)
    }

    func isChainHead(_ task: SchemaTask, in tasks: [SchemaTask]) -> Bool {
        RoutineSequenceOrdering.isChainHead(task, in: tasks)
    }

    @discardableResult
    func moveTasks(
        from sourceIndices: IndexSet,
        to destination: Int,
        in displayedTasks: [SchemaTask],
        allTasks: [SchemaTask]
    ) -> Bool {
        guard let firstIndex = sourceIndices.first,
              firstIndex < displayedTasks.count else { return false }

        let sourceTask = displayedTasks[firstIndex]

        if !RoutineSequenceOrdering.canMoveIndividually(sourceTask, in: displayedTasks) {
            return false
        }

        var tasksToMove: [SchemaTask]
        if RoutineSequenceOrdering.isChainHead(sourceTask, in: displayedTasks) {
            tasksToMove = RoutineSequenceOrdering.getChainMembers(startingFrom: sourceTask, in: displayedTasks)
        } else {
            tasksToMove = [sourceTask]
        }

        let movingIDs = Set(tasksToMove.map(\.id))
        let effectiveDestination = adjustedDestination(
            original: destination,
            sourceIndices: sourceIndices,
            chainSize: tasksToMove.count,
            displayedTasks: displayedTasks
        )

        let tasksWithoutMoving = displayedTasks.filter { !movingIDs.contains($0.id) }
        
        let (beforeIndex, afterIndex) = neighborIndices(
            forDestination: effectiveDestination,
            in: tasksWithoutMoving,
            originalTasks: displayedTasks,
            movingIDs: movingIDs
        )

        let beforeSortIndex = beforeIndex.map { tasksWithoutMoving[$0].manualSortIndex }
        let afterSortIndex = afterIndex.map { tasksWithoutMoving[$0].manualSortIndex }

        let newIndices = calculateNewSortIndices(
            count: tasksToMove.count,
            before: beforeSortIndex,
            after: afterSortIndex
        )

        for (index, task) in tasksToMove.enumerated() {
            task.manualSortIndex = newIndices[index]
        }

        if let listID = sourceTask.list?.id {
            compactManualSortIndices(forListID: listID, in: allTasks)
        }

        save()
        return true
    }

    private func adjustedDestination(
        original: Int,
        sourceIndices: IndexSet,
        chainSize: Int,
        displayedTasks: [SchemaTask]
    ) -> Int {
        guard let firstSource = sourceIndices.first else { return original }
        
        if original > firstSource {
            return original - chainSize
        }
        return original
    }

    private func neighborIndices(
        forDestination destination: Int,
        in filteredTasks: [SchemaTask],
        originalTasks: [SchemaTask],
        movingIDs: Set<UUID>
    ) -> (before: Int?, after: Int?) {
        if filteredTasks.isEmpty {
            return (nil, nil)
        }
        
        if destination <= 0 {
            return (nil, 0)
        }
        
        if destination >= filteredTasks.count {
            return (filteredTasks.count - 1, nil)
        }
        
        return (destination - 1, destination)
    }

    private func calculateNewSortIndices(
        count: Int,
        before: Double?,
        after: Double?
    ) -> [Double] {
        let start: Double
        let gap: Double

        switch (before, after) {
        case let (b?, a?):
            gap = (a - b) / Double(count + 1)
            start = b + gap
        case let (b?, nil):
            start = b + 1
            gap = 1
        case let (nil, a?):
            start = a - Double(count)
            gap = 1
        case (nil, nil):
            start = 1
            gap = 1
        }

        return (0..<count).map { start + Double($0) * gap }
    }

    func clearReminderTimes(for taskIDs: [UUID], in allTasks: [SchemaTask]) async {
        for taskID in taskIDs {
            guard let task = allTasks.first(where: { $0.id == taskID }) else { continue }
            await setReminder(task, at: nil)
        }
    }

    private func compactManualSortIndices(forListID listID: UUID, in allTasks: [SchemaTask]) {
        let listTasks = allTasks.filter { $0.list?.id == listID }
        guard !listTasks.isEmpty else { return }

        let ordered = applyManualSort(listTasks)
        for (index, task) in ordered.enumerated() {
            task.manualSortIndex = Double(index + 1)
        }
    }

    func toggleCompletion(_ task: SchemaTask, in allTasks: [SchemaTask], recordUndo: Bool = true) {
        if !task.isCompleted, isSequenceBlocked(task, in: allTasks) {
            return
        }

        if recordUndo {
            pushUndo(.toggledCompletion(taskID: task.id, wasCompleted: task.isCompleted))
        }

        task.isCompleted.toggle()
        save()

        if task.isCompleted {
            notificationService.cancelReminder(for: task)
        } else if task.isRoutine, task.reminderTime != nil {
            Task { await rescheduleReminderIfNeeded(for: task) }
        }
    }

    @discardableResult
    func duplicateTasks(_ tasks: [SchemaTask], allTasks: [SchemaTask] = [], recordUndo: Bool = true) -> [SchemaTask] {
        var copies: [SchemaTask] = []

        for (index, task) in tasks.enumerated() {
            guard let list = task.list else { continue }

            let copy = SchemaTask(
                title: task.title,
                description: task.taskDescription,
                list: list,
                reminderTime: task.reminderTime,
                tags: task.tags,
                isRoutine: task.isRoutine,
                routineDays: task.routineDays,
                afterTaskID: nil
            )
            copy.isCompleted = task.isCompleted
            copy.createdAt = task.createdAt.addingTimeInterval(Double(index + 1) * 0.001)
            copy.manualSortIndex = task.manualSortIndex + 0.001 * Double(index + 1)
            modelContext.insert(copy)
            copies.append(copy)

            if recordUndo {
                pushUndo(.addedTask(copy.id))
            }
        }

        guard !copies.isEmpty else { return [] }

        save()

        for copy in copies where copy.reminderTime != nil && !copy.isCompleted {
            Task { await rescheduleReminderIfNeeded(for: copy) }
        }

        return copies
    }

    func deleteTask(_ task: SchemaTask, recordUndo: Bool = true) {
        if recordUndo {
            pushUndo(.deletedTask(TaskSnapshot(task: task)))
        }

        clearSequenceLinks(pointingTo: task.id)
        notificationService.cancelReminder(for: task)

        if task.isRoutine, let listID = task.list?.id {
            let descriptor = FetchDescriptor<SchemaTask>()
            if let remaining = try? modelContext.fetch(descriptor) {
                RoutineSequenceOrdering.persistOrder(in: remaining, forListID: listID)
            }
        }

        modelContext.delete(task)
        save()
    }

    func updateTitle(_ task: SchemaTask, title: String, recordUndo: Bool = true) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if recordUndo, trimmed != task.title {
            pushUndo(.updatedTitle(taskID: task.id, previousTitle: task.title))
        }

        task.title = trimmed
        save()
    }

    func updateDescription(_ task: SchemaTask, description: String?) {
        let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskDescription = trimmed?.isEmpty == true ? nil : trimmed
        save()
    }

    @discardableResult
    func applyDetailChanges(
        _ task: SchemaTask,
        title: String,
        description: String?,
        reminder: Date?,
        isRoutine: Bool,
        routineDays: [Int],
        afterTaskID: UUID?,
        allTasks: [SchemaTask]
    ) async -> RoutineSequenceValidationResult? {
        if let validationFailure = RoutineSequenceOrdering.validateProposedSequenceState(
            for: task.id,
            title: title,
            isRoutine: isRoutine,
            afterTaskID: afterTaskID,
            reminderTime: reminder,
            in: allTasks
        ) {
            return validationFailure
        }

        updateTitle(task, title: title, recordUndo: true)
        updateDescription(task, description: description)

        if !isRoutine {
            RoutineSequenceOrdering.detachFollowers(from: task.id, in: allTasks)
        }

        task.isRoutine = isRoutine
        task.routineDays = isRoutine ? routineDays : []
        task.afterTaskID = isRoutine ? afterTaskID : nil

        if let afterTaskID = task.afterTaskID,
           RoutineSequenceOrdering.wouldCreateCycle(taskID: task.id, afterTaskID: afterTaskID, in: allTasks) {
            task.afterTaskID = nil
        }

        if task.isRoutine, task.afterTaskID != nil, let listID = task.list?.id {
            RoutineSequenceOrdering.persistOrder(in: allTasks, forListID: listID)
        }

        save()
        await setReminder(task, at: reminder)
        return nil
    }

    func setReminder(_ task: SchemaTask, at date: Date?) async {
        task.reminderTime = date
        save()

        if date == nil {
            notificationService.cancelReminder(for: task)
            return
        }

        if task.isRoutine || date! > Date() {
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

    func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case .addedTask(let id):
            if let task = fetchTask(id: id) {
                deleteTask(task, recordUndo: false)
            }
        case .deletedTask(let snapshot):
            restoreTask(snapshot)
        case .toggledCompletion(let taskID, let wasCompleted):
            if let task = fetchTask(id: taskID) {
                task.isCompleted = wasCompleted
                save()
                if wasCompleted {
                    Task { await rescheduleReminderIfNeeded(for: task) }
                } else {
                    notificationService.cancelReminder(for: task)
                }
            }
        case .updatedTitle(let taskID, let previousTitle):
            if let task = fetchTask(id: taskID) {
                task.title = previousTitle
                save()
            }
        }
    }

    private func restoreTask(_ snapshot: TaskSnapshot) {
        let list = snapshot.listID.flatMap { fetchList(id: $0) }
        let task = SchemaTask(
            title: snapshot.title,
            description: snapshot.taskDescription,
            list: list,
            reminderTime: snapshot.reminderTime,
            isRoutine: snapshot.isRoutine,
            routineDays: snapshot.routineDays,
            afterTaskID: snapshot.afterTaskID
        )
        task.id = snapshot.id
        task.isCompleted = snapshot.isCompleted
        task.createdAt = snapshot.createdAt
        task.manualSortIndex = snapshot.manualSortIndex
        modelContext.insert(task)
        save()

        if snapshot.reminderTime != nil, !snapshot.isCompleted {
            Task { await rescheduleReminderIfNeeded(for: task) }
        }
    }

    private func rescheduleReminderIfNeeded(for task: SchemaTask) async {
        guard let reminderTime = task.reminderTime, !task.isCompleted else { return }
        guard task.isRoutine || reminderTime > Date() else { return }
        do {
            let authorized = try await notificationService.requestAuthorization()
            guard authorized else { return }
            try await notificationService.scheduleReminder(for: task)
        } catch {
            assertionFailure("Failed to reschedule reminder: \(error)")
        }
    }

    private func fetchTask(id: UUID) -> SchemaTask? {
        var descriptor = FetchDescriptor<SchemaTask>(
            predicate: #Predicate<SchemaTask> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchList(id: UUID) -> SchemaList? {
        var descriptor = FetchDescriptor<SchemaList>(
            predicate: #Predicate<SchemaList> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func pushUndo(_ action: TaskUndoAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoCount {
            undoStack.removeFirst(undoStack.count - maxUndoCount)
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
            return applyManualSort(tasks)
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

    private func applyManualSort(_ tasks: [SchemaTask]) -> [SchemaTask] {
        let hasChains = tasks.contains { $0.isRoutine && $0.afterTaskID != nil }
        
        if !hasChains {
            return tasks.sorted { $0.manualSortIndex < $1.manualSortIndex }
        }
        
        let sortedByIndex = tasks.sorted { $0.manualSortIndex < $1.manualSortIndex }
        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let taskIDs = Set(taskByID.keys)
        var placed = Set<UUID>()
        var ordered: [SchemaTask] = []
        
        for task in sortedByIndex {
            guard !placed.contains(task.id) else { continue }
            
            if task.isRoutine,
               let afterID = task.afterTaskID,
               taskIDs.contains(afterID) {
                continue
            }
            
            if task.isRoutine, RoutineSequenceOrdering.isChainHead(task, in: tasks) {
                let chain = RoutineSequenceOrdering.getChainMembers(startingFrom: task, in: tasks)
                for chainTask in chain {
                    if !placed.contains(chainTask.id) {
                        ordered.append(chainTask)
                        placed.insert(chainTask.id)
                    }
                }
            } else {
                ordered.append(task)
                placed.insert(task.id)
            }
        }
        
        for task in sortedByIndex where !placed.contains(task.id) {
            ordered.append(task)
            placed.insert(task.id)
        }
        
        return ordered
    }

    private func clearSequenceLinks(pointingTo taskID: UUID) {
        let descriptor = FetchDescriptor<SchemaTask>()
        guard let tasks = try? modelContext.fetch(descriptor) else { return }

        for task in tasks where task.afterTaskID == taskID {
            task.afterTaskID = nil
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

//
//  RoutineSequenceOrdering.swift
//  Schema
//

import Foundation

struct RoutineSequenceValidationResult: Equatable {
    enum Kind: Equatable {
        case headerMustHaveTime
        case timeOutOfOrder(taskTitle: String, minimumTimeLabel: String)
    }

    let kind: Kind

    var message: String {
        switch kind {
        case .headerMustHaveTime:
            return "The first task in a routine sequence needs a time when later tasks have reminders set."
        case let .timeOutOfOrder(taskTitle, minimumTimeLabel):
            return "\(taskTitle) must be scheduled at or after \(minimumTimeLabel) to stay in order with the tasks before it."
        }
    }

    var suggestion: String {
        "Remove times from tasks after the first in this sequence, and keep only the header task's time to mark when the routine starts."
    }
}

enum RoutineSequenceOrdering {
    static func hasConnectedRoutineTasks(in tasks: [SchemaTask], forListID listID: UUID) -> Bool {
        let routineTasks = tasks.filter { $0.list?.id == listID && $0.isRoutine }
        guard routineTasks.count >= 2 else { return false }

        let routineIDs = Set(routineTasks.map(\.id))
        let linkedTasks = routineTasks.filter { task in
            if let afterID = task.afterTaskID, routineIDs.contains(afterID) {
                return true
            }
            return routineTasks.contains { $0.afterTaskID == task.id }
        }

        return linkedTasks.count >= 2
    }

    static func requiresManualSort(for list: SchemaList?, in tasks: [SchemaTask]) -> Bool {
        guard let list else { return false }

        if list.isEverythingList {
            let listIDs = Set(tasks.compactMap { $0.list?.id })
            return listIDs.contains { hasConnectedRoutineTasks(in: tasks, forListID: $0) }
        }

        return hasConnectedRoutineTasks(in: tasks, forListID: list.id)
    }

    static func persistOrder(in tasks: [SchemaTask], forListID listID: UUID) {
        let listTasks = tasks.filter { $0.list?.id == listID }
        guard listTasks.contains(where: { $0.isRoutine && $0.afterTaskID != nil }) else { return }

        let ordered = sorted(listTasks)
        guard let baseDate = ordered.map(\.createdAt).min() else { return }

        for (index, task) in ordered.enumerated() {
            task.createdAt = baseDate.addingTimeInterval(Double(index) * 0.001)
        }
    }

    static func sorted(_ tasks: [SchemaTask]) -> [SchemaTask] {
        guard tasks.contains(where: { $0.isRoutine && $0.afterTaskID != nil }) else {
            return tasks.sorted { $0.createdAt < $1.createdAt }
        }

        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let taskIDs = Set(taskByID.keys)
        var placed = Set<UUID>()
        var ordered: [SchemaTask] = []

        let sortedByCreation = tasks.sorted { $0.createdAt < $1.createdAt }

        for task in sortedByCreation {
            guard !placed.contains(task.id) else { continue }

            if task.isRoutine,
               let afterID = task.afterTaskID,
               taskIDs.contains(afterID) {
                continue
            }

            if task.isRoutine, isChainHead(task, taskIDs: taskIDs) {
                appendChain(startingFrom: task, taskByID: taskByID, placed: &placed, ordered: &ordered)
            } else {
                ordered.append(task)
                placed.insert(task.id)
            }
        }

        for task in sortedByCreation where !placed.contains(task.id) {
            ordered.append(task)
            placed.insert(task.id)
        }

        return ordered
    }

    static func isBlocked(
        _ task: SchemaTask,
        in tasks: [SchemaTask],
        allowIndependentFollowerCompletion: Bool? = nil
    ) -> Bool {
        let allowsIndependentFollowerCompletion = allowIndependentFollowerCompletion
            ?? SchemaPreferences.allowIndependentFollowerRoutineCompletion
        guard !allowsIndependentFollowerCompletion else { return false }
        guard task.isRoutine, let afterID = task.afterTaskID else { return false }
        guard let predecessor = tasks.first(where: { $0.id == afterID }) else { return false }
        return !predecessor.isCompleted
    }

    static func wouldCreateCycle(taskID: UUID, afterTaskID: UUID?, in tasks: [SchemaTask]) -> Bool {
        guard let afterTaskID else { return false }

        var current: UUID? = afterTaskID
        var visited = Set<UUID>()

        while let id = current {
            if id == taskID { return true }
            guard visited.insert(id).inserted else { return true }
            current = tasks.first(where: { $0.id == id })?.afterTaskID
        }

        return false
    }

    static func isChainHead(_ task: SchemaTask, in tasks: [SchemaTask]) -> Bool {
        guard task.isRoutine else { return false }
        let taskIDs = Set(tasks.map(\.id))
        return isChainHead(task, taskIDs: taskIDs)
    }

    static func getChainMembers(startingFrom head: SchemaTask, in tasks: [SchemaTask]) -> [SchemaTask] {
        guard head.isRoutine else { return [head] }
        
        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var chain: [SchemaTask] = []
        var current: SchemaTask? = head
        var visited = Set<UUID>()
        
        while let task = current, !visited.contains(task.id) {
            chain.append(task)
            visited.insert(task.id)
            current = taskByID.values.first { $0.afterTaskID == task.id }
        }
        
        return chain
    }

    static func canMoveIndividually(_ task: SchemaTask, in tasks: [SchemaTask]) -> Bool {
        guard task.isRoutine, task.afterTaskID != nil else { return true }
        
        let taskIDs = Set(tasks.map(\.id))
        guard let afterID = task.afterTaskID, taskIDs.contains(afterID) else {
            return true
        }
        return false
    }

    static func findChainHead(for task: SchemaTask, in tasks: [SchemaTask]) -> SchemaTask? {
        guard task.isRoutine else { return nil }
        
        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let taskIDs = Set(taskByID.keys)
        var current = task
        var visited = Set<UUID>()
        
        while let afterID = current.afterTaskID,
              taskIDs.contains(afterID),
              let predecessor = taskByID[afterID],
              !visited.contains(afterID) {
            visited.insert(current.id)
            current = predecessor
        }
        
        return current
    }

    static func detachFollowers(from taskID: UUID, in tasks: [SchemaTask]) {
        for task in tasks where task.afterTaskID == taskID {
            task.afterTaskID = nil
        }
    }

    static func routineMinutesFromMidnight(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return hour * 60 + minute
    }

    static func formattedRoutineTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func validateProposedSequenceState(
        for taskID: UUID,
        title: String,
        isRoutine: Bool,
        afterTaskID: UUID?,
        reminderTime: Date?,
        in allTasks: [SchemaTask]
    ) -> RoutineSequenceValidationResult? {
        guard let listID = allTasks.first(where: { $0.id == taskID })?.list?.id else { return nil }

        let simulated = simulatedRoutineTasks(
            in: allTasks,
            listID: listID,
            editingTaskID: taskID,
            title: title,
            isRoutine: isRoutine,
            afterTaskID: afterTaskID,
            reminderTime: reminderTime
        )

        for chain in connectedChains(in: simulated) where chain.count >= 2 {
            if let failure = validateChainTimeOrder(chain) {
                return failure
            }
        }

        return nil
    }

    static func validAfterCandidates(
        for taskID: UUID,
        title: String,
        reminderTime: Date?,
        candidates: [SchemaTask],
        in allTasks: [SchemaTask]
    ) -> [SchemaTask] {
        candidates.filter { candidate in
            guard !wouldCreateCycle(taskID: taskID, afterTaskID: candidate.id, in: allTasks) else {
                return false
            }

            return validateProposedSequenceState(
                for: taskID,
                title: title,
                isRoutine: true,
                afterTaskID: candidate.id,
                reminderTime: reminderTime,
                in: allTasks
            ) == nil
        }
    }

    static func followerIDsInProposedChain(
        containing taskID: UUID,
        title: String,
        isRoutine: Bool,
        afterTaskID: UUID?,
        reminderTime: Date?,
        in allTasks: [SchemaTask]
    ) -> [UUID] {
        guard let chain = proposedChain(
            containing: taskID,
            title: title,
            isRoutine: isRoutine,
            afterTaskID: afterTaskID,
            reminderTime: reminderTime,
            in: allTasks
        ) else {
            return []
        }

        return Array(chain.dropFirst().map(\.id))
    }

    private static func proposedChain(
        containing taskID: UUID,
        title: String,
        isRoutine: Bool,
        afterTaskID: UUID?,
        reminderTime: Date?,
        in allTasks: [SchemaTask]
    ) -> [SimulatedTask]? {
        guard let listID = allTasks.first(where: { $0.id == taskID })?.list?.id else { return nil }

        let simulated = simulatedRoutineTasks(
            in: allTasks,
            listID: listID,
            editingTaskID: taskID,
            title: title,
            isRoutine: isRoutine,
            afterTaskID: afterTaskID,
            reminderTime: reminderTime
        )

        for chain in connectedChains(in: simulated) where chain.count >= 2 {
            if chain.contains(where: { $0.id == taskID }) {
                return chain
            }
        }

        return nil
    }

    private struct SimulatedTask {
        let id: UUID
        let title: String
        var afterTaskID: UUID?
        var reminderTime: Date?
    }

    private static func simulatedRoutineTasks(
        in allTasks: [SchemaTask],
        listID: UUID,
        editingTaskID: UUID,
        title: String,
        isRoutine: Bool,
        afterTaskID: UUID?,
        reminderTime: Date?
    ) -> [SimulatedTask] {
        var simulated = allTasks
            .filter { $0.list?.id == listID && $0.isRoutine && $0.id != editingTaskID }
            .map {
                SimulatedTask(
                    id: $0.id,
                    title: $0.title,
                    afterTaskID: $0.afterTaskID,
                    reminderTime: $0.reminderTime
                )
            }

        if isRoutine {
            simulated.append(
                SimulatedTask(
                    id: editingTaskID,
                    title: title,
                    afterTaskID: afterTaskID,
                    reminderTime: reminderTime
                )
            )
        } else {
            for index in simulated.indices where simulated[index].afterTaskID == editingTaskID {
                simulated[index].afterTaskID = nil
            }
        }

        return simulated
    }

    private static func connectedChains(in tasks: [SimulatedTask]) -> [[SimulatedTask]] {
        guard !tasks.isEmpty else { return [] }

        let byID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let ids = Set(byID.keys)
        var visited = Set<UUID>()
        var chains: [[SimulatedTask]] = []

        let sortedByTitle = tasks.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        for task in sortedByTitle {
            guard !visited.contains(task.id) else { continue }

            let isNonHead = task.afterTaskID.map { ids.contains($0) } ?? false
            if isNonHead { continue }

            var chain: [SimulatedTask] = []
            var current: SimulatedTask? = task

            while let member = current, !visited.contains(member.id) {
                chain.append(member)
                visited.insert(member.id)
                current = byID.values.first { $0.afterTaskID == member.id }
            }

            if !chain.isEmpty {
                chains.append(chain)
            }
        }

        for task in sortedByTitle where !visited.contains(task.id) {
            chains.append([task])
        }

        return chains
    }

    private static func validateChainTimeOrder(_ chain: [SimulatedTask]) -> RoutineSequenceValidationResult? {
        guard chain.count >= 2 else { return nil }

        let minutes = chain.map { routineMinutesFromMidnight($0.reminderTime) }

        if minutes.dropFirst().contains(where: { $0 != nil }), minutes[0] == nil {
            return RoutineSequenceValidationResult(kind: .headerMustHaveTime)
        }

        var latestMinutes: Int?
        var latestTimeLabel: String?

        for (index, member) in chain.enumerated() {
            guard let currentMinutes = minutes[index] else { continue }

            if let latestMinutes, currentMinutes < latestMinutes {
                return RoutineSequenceValidationResult(
                    kind: .timeOutOfOrder(
                        taskTitle: member.title,
                        minimumTimeLabel: latestTimeLabel ?? formattedRoutineTime(member.reminderTime) ?? "the previous task"
                    )
                )
            }

            if latestMinutes == nil || currentMinutes >= latestMinutes! {
                latestMinutes = currentMinutes
                latestTimeLabel = formattedRoutineTime(member.reminderTime)
            }
        }

        return nil
    }

    private static func isChainHead(_ task: SchemaTask, taskIDs: Set<UUID>) -> Bool {
        guard let afterID = task.afterTaskID else { return true }
        return !taskIDs.contains(afterID)
    }

    private static func appendChain(
        startingFrom head: SchemaTask,
        taskByID: [UUID: SchemaTask],
        placed: inout Set<UUID>,
        ordered: inout [SchemaTask]
    ) {
        var current: SchemaTask? = head

        while let task = current, !placed.contains(task.id) {
            ordered.append(task)
            placed.insert(task.id)
            current = taskByID.values.first { $0.afterTaskID == task.id }
        }
    }
}

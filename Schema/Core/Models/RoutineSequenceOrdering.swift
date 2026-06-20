//
//  RoutineSequenceOrdering.swift
//  Schema
//

import Foundation

enum RoutineSequenceOrdering {
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

    static func isBlocked(_ task: SchemaTask, in tasks: [SchemaTask]) -> Bool {
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

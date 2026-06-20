//
//  TaskUndo.swift
//  Schema
//

import Foundation

struct TaskSnapshot {
    let id: UUID
    let title: String
    let taskDescription: String?
    let isCompleted: Bool
    let createdAt: Date
    let reminderTime: Date?
    let listID: UUID?
    let isRoutine: Bool
    let routineDays: [Int]
    let afterTaskID: UUID?
    let manualSortIndex: Double

    init(task: SchemaTask) {
        id = task.id
        title = task.title
        taskDescription = task.taskDescription
        isCompleted = task.isCompleted
        createdAt = task.createdAt
        reminderTime = task.reminderTime
        listID = task.list?.id
        isRoutine = task.isRoutine
        routineDays = task.routineDays
        afterTaskID = task.afterTaskID
        manualSortIndex = task.manualSortIndex
    }
}

enum TaskUndoAction {
    case addedTask(UUID)
    case deletedTask(TaskSnapshot)
    case toggledCompletion(taskID: UUID, wasCompleted: Bool)
    case updatedTitle(taskID: UUID, previousTitle: String)
}

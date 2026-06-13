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

    init(task: SchemaTask) {
        id = task.id
        title = task.title
        taskDescription = task.taskDescription
        isCompleted = task.isCompleted
        createdAt = task.createdAt
        reminderTime = task.reminderTime
        listID = task.list?.id
    }
}

enum TaskUndoAction {
    case addedTask(UUID)
    case deletedTask(TaskSnapshot)
    case toggledCompletion(taskID: UUID, wasCompleted: Bool)
    case updatedTitle(taskID: UUID, previousTitle: String)
}

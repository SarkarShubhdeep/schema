//
//  SchemaTask.swift
//  Schema
//

import Foundation
import SwiftData

@Model
final class SchemaTask {
    var id: UUID
    var title: String
    var taskDescription: String?
    var isCompleted: Bool
    var createdAt: Date
    var reminderTime: Date?
    var tags: [String]
    var isRoutine: Bool = false
    var routineDays: [Int] = []
    var lastRoutineReset: Date?
    var afterTaskID: UUID?
    var manualSortIndex: Double = 0
    /// When the task was last completed (schema V5). Kept when a routine
    /// resets for a new day, so the week chart still counts that day.
    var completedAt: Date?

    var list: SchemaList?

    /// The task's page body (schema V6, used by tasks as pages, #31).
    @Relationship(deleteRule: .cascade, inverse: \SchemaBlock.task)
    var blocks: [SchemaBlock] = []

    init(
        title: String,
        description: String? = nil,
        list: SchemaList? = nil,
        reminderTime: Date? = nil,
        tags: [String]? = nil,
        isRoutine: Bool = false,
        routineDays: [Int] = [],
        afterTaskID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.taskDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.list = list
        self.isCompleted = false
        self.createdAt = Date()
        self.reminderTime = reminderTime
        self.tags = tags ?? [list?.title].compactMap { $0 }
        self.isRoutine = isRoutine
        self.routineDays = routineDays
        self.lastRoutineReset = nil
        self.afterTaskID = afterTaskID
        self.blocks = []
    }
}

extension SchemaTask {
    /// Marks the task done or open, keeping `completedAt` in step.
    func setCompleted(_ completed: Bool, at date: Date = .now) {
        isCompleted = completed
        completedAt = completed ? date : nil
    }

    /// Done on the same calendar day as `date`.
    func wasCompleted(onSameDayAs date: Date, calendar: Calendar = .current) -> Bool {
        guard let completedAt else { return false }
        return calendar.isDate(completedAt, inSameDayAs: date)
    }

    var orderedBlocks: [SchemaBlock] { blocks.inDisplayOrder }

    static let allRoutineWeekdays: [Int] = [2, 3, 4, 5, 6, 7, 1]

    var displayDescription: String? {
        guard let taskDescription, !taskDescription.isEmpty else { return nil }
        return taskDescription
    }

    var effectiveRoutineDays: Set<Int> {
        if routineDays.isEmpty, isRoutine {
            return Set(Self.allRoutineWeekdays)
        }
        return Set(routineDays)
    }
}

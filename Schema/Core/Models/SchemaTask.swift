//
//  SchemaTask.swift
//  Schema
//

import Foundation
import SwiftData

@Model
final class SchemaTask: PageDocumentHolder {
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

    /// V6 page-body lines; empty since V7 moved them into `documentData`.
    @Relationship(deleteRule: .cascade, inverse: \SchemaBlock.task)
    var blocks: [SchemaBlock] = []

    // The page body as one TipTap document (schema V7, #77), and what is
    // derived from it on save so lists and search never parse it.
    @Attribute(.externalStorage) var documentData: Data?
    var documentText: String = ""
    var linkedTaskIDsRaw: String = ""
    var checklistCount: Int = 0
    var checklistDoneCount: Int = 0
    var documentEditedAt: Date?

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

    static let allRoutineWeekdays: [Int] = [2, 3, 4, 5, 6, 7, 1]

    /// The second line under a task's title in lists: the first line of
    /// its page body, or its older notes field.
    var displayDescription: String? {
        if let line = documentText.split(separator: "\n").first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return String(line)
        }
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

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

    var list: SchemaList?

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
    }
}

extension SchemaTask {
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

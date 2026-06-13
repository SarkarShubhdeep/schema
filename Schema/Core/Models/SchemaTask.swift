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

    var list: SchemaList?

    init(
        title: String,
        description: String? = nil,
        list: SchemaList? = nil,
        reminderTime: Date? = nil,
        tags: [String]? = nil
    ) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.taskDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.list = list
        self.isCompleted = false
        self.createdAt = Date()
        self.reminderTime = reminderTime
        self.tags = tags ?? [list?.title].compactMap { $0 }
    }
}

extension SchemaTask {
    var displayDescription: String? {
        guard let taskDescription, !taskDescription.isEmpty else { return nil }
        return taskDescription
    }
}

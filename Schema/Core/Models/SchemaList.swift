//
//  SchemaList.swift
//  Schema
//

import Foundation
import SwiftData

@Model
final class SchemaList {
    var id: UUID
    var title: String
    var createdAt: Date
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \SchemaTask.list)
    var tasks: [SchemaTask]

    init(title: String, order: Int = 0) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
        self.order = order
        self.tasks = []
    }
}

extension SchemaList {
    static let everythingTitle = "Everything"

    var isEverythingList: Bool {
        title == Self.everythingTitle
    }

    var incompleteTasks: [SchemaTask] {
        tasks.filter { !$0.isCompleted }.sorted { $0.createdAt < $1.createdAt }
    }

    var completedTasks: [SchemaTask] {
        tasks.filter(\.isCompleted).sorted { $0.createdAt < $1.createdAt }
    }
}

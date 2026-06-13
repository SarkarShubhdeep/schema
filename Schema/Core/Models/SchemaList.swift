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
    var accentColorName: String?
    var tagLabel: String?

    @Relationship(deleteRule: .cascade, inverse: \SchemaTask.list)
    var tasks: [SchemaTask]

    init(
        title: String,
        order: Int = 0,
        accentColorName: String? = nil,
        tagLabel: String? = nil
    ) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
        self.order = order
        self.accentColorName = accentColorName
        self.tagLabel = tagLabel
        self.tasks = []
    }
}

extension SchemaList {
    static let everythingTitle = "Everything"

    var isEverythingList: Bool {
        title == Self.everythingTitle
    }

    var displayTagLabel: String {
        if let tagLabel, !tagLabel.isEmpty {
            return tagLabel
        }
        return title
    }

    var incompleteTasks: [SchemaTask] {
        tasks.filter { !$0.isCompleted }.sorted { $0.createdAt < $1.createdAt }
    }

    var completedTasks: [SchemaTask] {
        tasks.filter(\.isCompleted).sorted { $0.createdAt < $1.createdAt }
    }

    var incompleteTaskCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
}

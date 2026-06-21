//
//  SchemaMigrationPlan.swift
//  Schema
//

import Foundation
import SwiftData

enum SchemaMigrationV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [List.self, Task.self]
    }

    @Model
    final class List {
        var id: UUID
        var title: String
        var createdAt: Date
        var order: Int

        @Relationship(deleteRule: .cascade, inverse: \Task.list)
        var tasks: [Task]

        init(id: UUID = UUID(), title: String, createdAt: Date = .now, order: Int = 0) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.order = order
            self.tasks = []
        }
    }

    @Model
    final class Task {
        var id: UUID
        var title: String
        var taskDescription: String?
        var isCompleted: Bool
        var createdAt: Date
        var reminderTime: Date?
        var tags: [String]

        var list: List?

        init(
            id: UUID = UUID(),
            title: String,
            taskDescription: String? = nil,
            isCompleted: Bool = false,
            createdAt: Date = .now,
            reminderTime: Date? = nil,
            tags: [String] = []
        ) {
            self.id = id
            self.title = title
            self.taskDescription = taskDescription
            self.isCompleted = isCompleted
            self.createdAt = createdAt
            self.reminderTime = reminderTime
            self.tags = tags
        }
    }
}

enum SchemaMigrationV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [List.self, Task.self]
    }

    @Model
    final class List {
        var id: UUID
        var title: String
        var createdAt: Date
        var order: Int
        var accentColorName: String?
        var tagLabel: String?

        @Relationship(deleteRule: .cascade, inverse: \Task.list)
        var tasks: [Task]

        init(
            id: UUID = UUID(),
            title: String,
            createdAt: Date = .now,
            order: Int = 0,
            accentColorName: String? = nil,
            tagLabel: String? = nil
        ) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.order = order
            self.accentColorName = accentColorName
            self.tagLabel = tagLabel
            self.tasks = []
        }
    }

    @Model
    final class Task {
        var id: UUID
        var title: String
        var taskDescription: String?
        var isCompleted: Bool
        var createdAt: Date
        var reminderTime: Date?
        var tags: [String]

        var list: List?

        init(
            id: UUID = UUID(),
            title: String,
            taskDescription: String? = nil,
            isCompleted: Bool = false,
            createdAt: Date = .now,
            reminderTime: Date? = nil,
            tags: [String] = []
        ) {
            self.id = id
            self.title = title
            self.taskDescription = taskDescription
            self.isCompleted = isCompleted
            self.createdAt = createdAt
            self.reminderTime = reminderTime
            self.tags = tags
        }
    }
}

enum SchemaMigrationV3: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [List.self, Task.self]
    }

    @Model
    final class List {
        var id: UUID
        var title: String
        var createdAt: Date
        var order: Int
        var accentColorName: String?
        var tagLabel: String?

        @Relationship(deleteRule: .cascade, inverse: \Task.list)
        var tasks: [Task]

        init(
            id: UUID = UUID(),
            title: String,
            createdAt: Date = .now,
            order: Int = 0,
            accentColorName: String? = nil,
            tagLabel: String? = nil
        ) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.order = order
            self.accentColorName = accentColorName
            self.tagLabel = tagLabel
            self.tasks = []
        }
    }

    @Model
    final class Task {
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

        var list: List?

        init(
            id: UUID = UUID(),
            title: String,
            taskDescription: String? = nil,
            isCompleted: Bool = false,
            createdAt: Date = .now,
            reminderTime: Date? = nil,
            tags: [String] = [],
            isRoutine: Bool = false,
            routineDays: [Int] = [],
            lastRoutineReset: Date? = nil,
            afterTaskID: UUID? = nil
        ) {
            self.id = id
            self.title = title
            self.taskDescription = taskDescription
            self.isCompleted = isCompleted
            self.createdAt = createdAt
            self.reminderTime = reminderTime
            self.tags = tags
            self.isRoutine = isRoutine
            self.routineDays = routineDays
            self.lastRoutineReset = lastRoutineReset
            self.afterTaskID = afterTaskID
        }
    }
}

enum SchemaMigrationV4: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaList.self, SchemaTask.self]
    }
}

enum SchemaAppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaMigrationV1.self,
            SchemaMigrationV2.self,
            SchemaMigrationV3.self,
            SchemaMigrationV4.self,
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaMigrationV1.self,
        toVersion: SchemaMigrationV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaMigrationV2.self,
        toVersion: SchemaMigrationV3.self
    )

    static let migrateV3toV4 = MigrationStage.custom(
        fromVersion: SchemaMigrationV3.self,
        toVersion: SchemaMigrationV4.self,
        willMigrate: nil,
        didMigrate: { context in
            let tasks = try context.fetch(FetchDescriptor<SchemaTask>())
            let grouped = Dictionary(grouping: tasks) { $0.list?.id }

            for (_, listTasks) in grouped {
                let ordered = listTasks.sorted { $0.createdAt < $1.createdAt }
                for (index, task) in ordered.enumerated() {
                    task.manualSortIndex = Double(index + 1)
                }
            }

            try context.save()
        }
    )
}

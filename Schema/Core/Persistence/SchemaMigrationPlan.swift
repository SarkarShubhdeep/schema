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

/// V4 frozen as it shipped (v0.3): the live models before `completedAt`.
/// Class names match the live ones so the stored entity names stay the same.
enum SchemaMigrationV4: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaList.self, SchemaTask.self]
    }

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

        init(id: UUID = UUID(), title: String, createdAt: Date = .now, order: Int = 0) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.order = order
            self.tasks = []
        }
    }

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

        var list: SchemaList?

        init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
            self.id = id
            self.title = title
            self.isCompleted = false
            self.createdAt = createdAt
            self.tags = []
        }
    }
}

/// V5 frozen as it shipped (v0.4): adds `SchemaTask.completedAt` (#16).
/// Class names match the live ones so the stored entity names stay the same.
enum SchemaMigrationV5: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(5, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaList.self, SchemaTask.self]
    }

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

        init(id: UUID = UUID(), title: String, createdAt: Date = .now, order: Int = 0) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.order = order
            self.tasks = []
        }
    }

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
        var completedAt: Date?

        var list: SchemaList?

        init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
            self.id = id
            self.title = title
            self.isCompleted = false
            self.createdAt = createdAt
            self.tags = []
        }
    }
}

/// V6 frozen as it shipped (v0.5): page types and blocks (#36), with
/// `SchemaList.pageKindRaw`, the `SchemaBlock` model and block
/// relationships on pages and tasks. Class names match the live ones.
enum SchemaMigrationV6: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(6, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaList.self, SchemaTask.self, SchemaBlock.self]
    }

    @Model
    final class SchemaList {
        var id: UUID
        var title: String
        var createdAt: Date
        var order: Int
        var accentColorName: String?
        var tagLabel: String?
        var pageKindRaw: String = "todo"

        @Relationship(deleteRule: .cascade, inverse: \SchemaTask.list)
        var tasks: [SchemaTask]

        @Relationship(deleteRule: .cascade, inverse: \SchemaBlock.page)
        var blocks: [SchemaBlock] = []

        init(title: String, order: Int = 0, kindRaw: String = "todo") {
            self.id = UUID()
            self.title = title
            self.createdAt = .now
            self.order = order
            self.pageKindRaw = kindRaw
            self.tasks = []
            self.blocks = []
        }
    }

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
        var completedAt: Date?

        var list: SchemaList?

        @Relationship(deleteRule: .cascade, inverse: \SchemaBlock.task)
        var blocks: [SchemaBlock] = []

        init(title: String) {
            self.id = UUID()
            self.title = title
            self.isCompleted = false
            self.createdAt = .now
            self.tags = []
            self.blocks = []
        }
    }

    @Model
    final class SchemaBlock {
        var id: UUID
        var kindRaw: String = "text"
        var text: String = ""
        var isChecked: Bool = false
        var sortIndex: Double = 0
        var createdAt: Date
        var updatedAt: Date
        var linkedTaskID: UUID?

        var page: SchemaList?
        var task: SchemaTask?

        init(kindRaw: String = "text", text: String = "", sortIndex: Double) {
            self.id = UUID()
            self.kindRaw = kindRaw
            self.text = text
            self.sortIndex = sortIndex
            self.createdAt = .now
            self.updatedAt = .now
        }
    }
}

/// V7 stores each page and task body as one TipTap document (#77), with a
/// plain-text copy for search. Blocks stay in the schema only so the
/// migration can read them; it empties them. Uses the live models.
enum SchemaMigrationV7: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(7, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaList.self, SchemaTask.self, SchemaBlock.self]
    }
}

/// V8 adds Pomodoro timers and their finished focus sessions (#89). Pages
/// and tasks are unchanged. Uses the live models.
enum SchemaMigrationV8: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(8, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaList.self, SchemaTask.self, SchemaBlock.self, PomodoroTimer.self, PomodoroSession.self]
    }
}

/// The schema the app opens its store with.
typealias SchemaCurrentVersion = SchemaMigrationV8

enum SchemaAppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaMigrationV1.self,
            SchemaMigrationV2.self,
            SchemaMigrationV3.self,
            SchemaMigrationV4.self,
            SchemaMigrationV5.self,
            SchemaMigrationV6.self,
            SchemaMigrationV7.self,
            SchemaMigrationV8.self,
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8]
    }

    /// Adds the optional `completedAt`. Tasks already done keep it empty:
    /// their real completion time was never recorded, and guessing would
    /// put them on the wrong day in "Done today" and the week chart.
    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaMigrationV4.self,
        toVersion: SchemaMigrationV5.self
    )

    /// Adds `pageKindRaw` (default "todo", so every existing page stays a
    /// to-do list) and the empty block store. No data is rewritten.
    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: SchemaMigrationV5.self,
        toVersion: SchemaMigrationV6.self
    )

    /// Moves every page's and task's lines into one TipTap document,
    /// keeping each to-do's link to its task, then deletes the lines.
    static let migrateV6toV7 = MigrationStage.custom(
        fromVersion: SchemaMigrationV6.self,
        toVersion: SchemaMigrationV7.self,
        willMigrate: nil,
        didMigrate: { context in
            try PageDocumentMigration.moveBlocksIntoDocuments(in: context)
            try context.save()
        }
    )

    /// Adds the two Pomodoro tables; nothing else changes.
    static let migrateV7toV8 = MigrationStage.lightweight(
        fromVersion: SchemaMigrationV7.self,
        toVersion: SchemaMigrationV8.self
    )

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
            let tasks = try context.fetch(FetchDescriptor<SchemaMigrationV4.SchemaTask>())
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

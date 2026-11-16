//
//  MigrationV6Tests.swift
//  SchemaTests
//
//  Builds a V5 store on disk with the frozen V5 models, then opens it with
//  the full migration plan and checks nothing was lost on the way to V6.
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct MigrationV6Tests {
    @Test func v5StoreMigratesToV6WithoutLosingData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaMigrationV6Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Schema.store")

        let listID: UUID
        let doneID: UUID
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)

        // A V5 store as v0.4 leaves it: one page, two tasks, one completed.
        do {
            let schema = Schema(versionedSchema: SchemaMigrationV5.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let list = SchemaMigrationV5.SchemaList(title: "Daily Todos", order: 1)
            context.insert(list)
            let open = SchemaMigrationV5.SchemaTask(title: "Water the plants")
            open.list = list
            open.manualSortIndex = 1
            let done = SchemaMigrationV5.SchemaTask(title: "Book dentist")
            done.list = list
            done.isCompleted = true
            done.completedAt = completedAt
            done.manualSortIndex = 2
            context.insert(open)
            context.insert(done)
            try context.save()
            listID = list.id
            doneID = done.id
        }

        // Open it as the app does: current schema plus the migration plan.
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SchemaAppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = container.mainContext
        let lists = try context.fetch(FetchDescriptor<SchemaList>())
        let tasks = try context.fetch(FetchDescriptor<SchemaTask>())

        #expect(lists.count == 1)
        #expect(tasks.count == 2)
        let list = try #require(lists.first)
        #expect(list.id == listID)
        #expect(list.title == "Daily Todos")
        #expect(list.pageKind == .todo)
        #expect(list.blocks.isEmpty)

        let done = try #require(tasks.first { $0.id == doneID })
        #expect(done.isCompleted)
        #expect(done.completedAt == completedAt)
        #expect(done.list?.id == listID)
        #expect(done.blocks.isEmpty)
        #expect(Set(tasks.map(\.manualSortIndex)) == [1, 2])
        #expect(try context.fetchCount(FetchDescriptor<SchemaBlock>()) == 0)
    }
}

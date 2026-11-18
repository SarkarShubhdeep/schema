//
//  MigrationV7Tests.swift
//  SchemaTests
//
//  Builds a V6 store on disk with the frozen V6 models (a scratchpad with a
//  to-do made into a task, a task page body, a task with old notes), then
//  opens it with the full plan and checks the lines became documents (#77).
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct MigrationV7Tests {
    @Test func v6LinesBecomeDocumentsAndKeepTheirTasks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaMigrationV7Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Schema.store")

        let ideasID: UUID
        let linkedID: UUID
        let bodyTaskID: UUID
        let notesTaskID: UUID

        do {
            typealias V6 = SchemaMigrationV6
            let schema = Schema(versionedSchema: V6.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let work = V6.SchemaList(title: "Work", order: 1)
            let ideas = V6.SchemaList(title: "Ideas", order: 2, kindRaw: "scratchpad")
            context.insert(work)
            context.insert(ideas)

            let linked = V6.SchemaTask(title: "Sketch the panel")
            linked.list = work
            let bodyTask = V6.SchemaTask(title: "Call the landlord")
            bodyTask.list = work
            let notesTask = V6.SchemaTask(title: "Water plants")
            notesTask.list = work
            notesTask.taskDescription = "Twice a week"
            [linked, bodyTask, notesTask].forEach(context.insert)

            func line(_ kind: String, _ text: String, _ index: Double, checked: Bool = false) -> V6.SchemaBlock {
                let block = V6.SchemaBlock(kindRaw: kind, text: text, sortIndex: index)
                block.isChecked = checked
                context.insert(block)
                return block
            }
            // Added out of order: sortIndex decides.
            line("todo", "Decide on page types", 3).page = ideas
            line("text", "First thought\nsecond line", 1).page = ideas
            let made = line("todo", "Sketch the panel", 2)
            made.linkedTaskID = linked.id
            made.page = ideas
            line("divider", "", 4).page = ideas

            line("heading", "Before calling", 1).task = bodyTask
            line("todo", "Find the lease", 2, checked: true).task = bodyTask
            try context.save()

            ideasID = ideas.id
            linkedID = linked.id
            bodyTaskID = bodyTask.id
            notesTaskID = notesTask.id
        }

        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SchemaAppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = container.mainContext
        let lists = try context.fetch(FetchDescriptor<SchemaList>())
        let tasks = try context.fetch(FetchDescriptor<SchemaTask>())
        #expect(lists.count == 2)
        #expect(tasks.count == 3)
        #expect(try context.fetchCount(FetchDescriptor<SchemaBlock>()) == 0)

        let ideas = try #require(lists.first { $0.id == ideasID })
        #expect(ideas.pageKind == .scratchpad)
        #expect(ideas.documentText == "First thought\nsecond line\nSketch the panel\nDecide on page types")
        #expect(ideas.linkedTaskIDs == [linkedID])
        #expect(ideas.checklistCount == 2)
        let node = try #require(PageDocument.parse(ideas.documentJSON))
        let types = (node["content"] as? [TipTapDocument.Node] ?? []).compactMap { $0["type"] as? String }
        #expect(types == ["paragraph", "taskList", "horizontalRule"])

        let body = try #require(tasks.first { $0.id == bodyTaskID })
        #expect(body.documentText == "Before calling\nFind the lease")
        #expect(body.checklistCount == 1)
        #expect(body.checklistDoneCount == 1)

        let notes = try #require(tasks.first { $0.id == notesTaskID })
        #expect(notes.documentText == "Twice a week")
        #expect(notes.taskDescription == nil)
        #expect(notes.displayDescription == "Twice a week")

        let work = try #require(lists.first { $0.title == "Work" })
        #expect(!work.hasDocument)
    }
}

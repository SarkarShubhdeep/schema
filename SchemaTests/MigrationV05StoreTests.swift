//
//  MigrationV05StoreTests.swift
//  SchemaTests
//
//  Updating from v0.5 (#84): a v0.5 store (schema V6) with real-looking
//  data, migrated to today's schema (V8) on disk. Six pages, 300 tasks with
//  routines, reminders, done dates, tags and "after" chains, a long
//  scratchpad with every kind of line and to-dos made into tasks, and task
//  pages with bodies and old notes. Nothing may be lost or changed.
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct MigrationV05StoreTests {
    private struct TaskFacts: Equatable {
        var title: String
        var listTitle: String?
        var isCompleted: Bool
        var completedAt: Date?
        var reminderTime: Date?
        var tags: [String]
        var isRoutine: Bool
        var routineDays: [Int]
        var afterTaskID: UUID?
        var manualSortIndex: Double
    }

    @Test func aFullV05StoreUpdatesWithNothingLost() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaV05Store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Schema.store")
        let base = Date(timeIntervalSince1970: 1_794_816_000) // 16 Nov 2026

        var before: [UUID: TaskFacts] = [:]
        var pageIDs: [String: UUID] = [:]
        var expectedJournalLines: [String] = []
        var expectedLinks: [UUID] = []
        var expectedChecklist = (count: 0, done: 0)
        var bodyTaskID = UUID()
        var notesTaskID = UUID()

        // MARK: A v0.5 store
        do {
            typealias V6 = SchemaMigrationV6
            let schema = Schema(versionedSchema: V6.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext

            let everything = V6.SchemaList(title: "Everything", order: 0)
            let pages = [("Daily Todos", "todo"), ("Work", "todo"), ("Groceries", "todo"), ("Reading", "todo"), ("Ideas", "scratchpad"), ("Journal", "scratchpad")]
                .enumerated().map { V6.SchemaList(title: $1.0, order: $0 + 1, kindRaw: $1.1) }
            context.insert(everything)
            pages.forEach(context.insert)
            for page in [everything] + pages { pageIDs[page.title] = page.id }
            let todoLists = pages.filter { $0.pageKindRaw == "todo" }

            var tasks: [V6.SchemaTask] = []
            for n in 0..<300 {
                let task = V6.SchemaTask(title: "Task \(n): \(["Call", "Email", "Buy", "Read", "Plan"][n % 5]) item \(n)")
                task.list = todoLists[n % todoLists.count]
                task.createdAt = base.addingTimeInterval(Double(n) * 600)
                task.manualSortIndex = Double(n / todoLists.count) + 1
                task.tags = n % 7 == 0 ? ["urgent", task.list?.title ?? ""] : [task.list?.title ?? ""]
                if n % 3 == 0 { task.reminderTime = base.addingTimeInterval(Double(n) * 3600) }
                if n % 4 == 0 {
                    task.isCompleted = true
                    task.completedAt = base.addingTimeInterval(Double(n) * 1800)
                }
                if n % 25 == 0 {
                    task.isRoutine = true
                    task.routineDays = [1, 3, 5]
                    task.lastRoutineReset = base
                }
                if n % 10 == 9, let previous = tasks.last { task.afterTaskID = previous.id }
                context.insert(task)
                tasks.append(task)
            }

            // A long scratchpad with every kind of line, some made into tasks.
            let journal = pages.first { $0.title == "Journal" }!
            let kinds = ["heading", "text", "bullet", "bullet", "todo", "quote", "todo", "text", "divider"]
            for n in 0..<150 {
                let kind = kinds[n % kinds.count]
                let text = kind == "divider" ? "" : (kind == "text" && n % 2 == 0 ? "Entry \(n)\nsecond line \(n)" : "Line \(n) \(kind)")
                let block = V6.SchemaBlock(kindRaw: kind, text: text, sortIndex: Double(150 - n))
                block.page = journal
                if kind == "todo" {
                    block.isChecked = n % 3 == 0
                    if n % 4 == 0 { block.linkedTaskID = tasks[n].id }
                }
                context.insert(block)
            }
            // sortIndex runs backwards, so the page reads from line 149 down to 0.
            for n in (0..<150).reversed() {
                let kind = kinds[n % kinds.count]
                guard kind != "divider" else { continue }
                if kind == "text" && n % 2 == 0 {
                    expectedJournalLines += ["Entry \(n)", "second line \(n)"]
                } else {
                    expectedJournalLines.append("Line \(n) \(kind)")
                }
                if kind == "todo" {
                    expectedChecklist.count += 1
                    if n % 3 == 0 { expectedChecklist.done += 1 }
                    if n % 4 == 0 { expectedLinks.append(tasks[n].id) }
                }
            }

            // A task page with a body, and one with only old notes.
            let bodyTask = tasks[1]
            for (index, (kind, text)) in [("heading", "Before calling"), ("todo", "Find the lease"), ("text", "Ask about the radiator")].enumerated() {
                let block = V6.SchemaBlock(kindRaw: kind, text: text, sortIndex: Double(index + 1))
                block.task = bodyTask
                context.insert(block)
            }
            bodyTask.taskDescription = "Landlord: 555-0100"
            tasks[2].taskDescription = "Twice a week\nmore if hot"
            bodyTaskID = bodyTask.id
            notesTaskID = tasks[2].id

            try context.save()
            for task in tasks {
                before[task.id] = TaskFacts(
                    title: task.title, listTitle: task.list?.title, isCompleted: task.isCompleted,
                    completedAt: task.completedAt, reminderTime: task.reminderTime, tags: task.tags,
                    isRoutine: task.isRoutine, routineDays: task.routineDays, afterTaskID: task.afterTaskID,
                    manualSortIndex: task.manualSortIndex
                )
            }
        }

        // MARK: Opened by today's app
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SchemaAppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = container.mainContext
        let lists = try context.fetch(FetchDescriptor<SchemaList>())
        let tasks = try context.fetch(FetchDescriptor<SchemaTask>())

        #expect(Dictionary(uniqueKeysWithValues: lists.map { ($0.title, $0.id) }) == pageIDs)
        #expect(lists.filter(\.isScratchpad).map(\.title).sorted() == ["Ideas", "Journal"])
        #expect(try context.fetchCount(FetchDescriptor<SchemaBlock>()) == 0)

        // Every task, field by field.
        #expect(tasks.count == 300)
        for task in tasks {
            let facts = TaskFacts(
                title: task.title, listTitle: task.list?.title, isCompleted: task.isCompleted,
                completedAt: task.completedAt, reminderTime: task.reminderTime, tags: task.tags,
                isRoutine: task.isRoutine, routineDays: task.routineDays, afterTaskID: task.afterTaskID,
                manualSortIndex: task.manualSortIndex
            )
            #expect(before[task.id] == facts, "\(task.title)")
        }

        // The long scratchpad, in order, with its to-dos and links.
        let journal = try #require(lists.first { $0.title == "Journal" })
        #expect(journal.documentText.components(separatedBy: "\n") == expectedJournalLines)
        #expect(journal.linkedTaskIDs == expectedLinks)
        #expect(journal.checklistCount == expectedChecklist.count)
        #expect(journal.checklistDoneCount == expectedChecklist.done)
        // Linked to-dos show their task's state when the page opens.
        let shown = PageDocument.applyingTaskStates(to: journal.documentJSON) { id in tasks.first { $0.id == id }?.isCompleted }
        let linkedDone = PageDocument.toDos(in: try #require(PageDocument.parse(shown))).filter { $0.taskID != nil && $0.isChecked }.count
        #expect(linkedDone == expectedLinks.filter { id in tasks.first { $0.id == id }?.isCompleted == true }.count)

        // An empty scratchpad stays empty.
        let ideas = try #require(lists.first { $0.title == "Ideas" })
        #expect(ideas.documentText.isEmpty)

        // Task pages: the body, with old notes first; notes alone.
        let body = try #require(tasks.first { $0.id == bodyTaskID })
        #expect(body.documentText == "Landlord: 555-0100\nBefore calling\nFind the lease\nAsk about the radiator")
        #expect(body.checklistCount == 1)
        let notes = try #require(tasks.first { $0.id == notesTaskID })
        #expect(notes.documentText == "Twice a week\nmore if hot")
        #expect(notes.taskDescription == nil)

        // Pomodoro (V8) starts empty and works in the updated store.
        #expect(try context.fetchCount(FetchDescriptor<PomodoroTimer>()) == 0)
        context.insert(PomodoroTimer(name: "Write", focusMinutes: 25, breakMinutes: 5, startsPhasesAutomatically: true))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<PomodoroTimer>()) == 1)
    }

    /// 0.5.1 left a task's old notes in the notes field when the task also
    /// had a body, so they were out of sight. Launch moves them in (#84).
    @Test func notesLeftBy051MoveAboveTheBody() throws {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let both = SchemaTask(title: "Call the landlord", description: "Landlord: 555-0100")
        both.setDocument(TipTapDocument.json(TipTapDocument.document(from: [TipTapDocument.Line(kind: .todo, text: "Find the lease")])))
        let plain = SchemaTask(title: "Plain")
        [both, plain].forEach(context.insert)
        try context.save()

        PageDocumentMigration.moveLeftoverNotes(in: context)
        #expect(both.documentText == "Landlord: 555-0100\nFind the lease")
        #expect(both.taskDescription == nil)
        #expect(both.checklistCount == 1)
        #expect(!plain.hasDocument)

        // Running again changes nothing.
        PageDocumentMigration.moveLeftoverNotes(in: context)
        #expect(both.documentText == "Landlord: 555-0100\nFind the lease")
    }
}

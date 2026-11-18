//
//  MigrationSelfTest.swift
//  Schema
//
//  DEBUG only. With SCHEMA_MIGRATION_SELFTEST=1 the app copies its own
//  store twice inside its container, reads copy A as V6 (no migration) and
//  migrates copy B to the current schema (V7), prints a comparison to
//  stdout and exits. The real
//  store is only read, never opened by SwiftData here.
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum MigrationSelfTest {
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["SCHEMA_MIGRATION_SELFTEST"] == "1"
    }

    static func runAndExit() -> Never {
        do {
            print(try run())
            exit(0)
        } catch {
            print("MIGRATION SELFTEST FAILED: \(error)")
            exit(1)
        }
    }

    private static func run() throws -> String {
        let source = ModelContainerFactory.storeURL()
        let root = source.deletingLastPathComponent().appendingPathComponent("MigrationSelfTest", isDirectory: true)
        let fm = FileManager.default
        try? fm.removeItem(at: root)
        let copyA = root.appendingPathComponent("A/Schema.store")
        let copyB = root.appendingPathComponent("B/Schema.store")
        for copy in [copyA, copyB] {
            try fm.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let from = URL(fileURLWithPath: source.path + suffix)
                if fm.fileExists(atPath: from.path) {
                    try fm.copyItem(at: from, to: URL(fileURLWithPath: copy.path + suffix))
                }
            }
        }
        defer { try? fm.removeItem(at: root) }

        // A: the store as it is today, read with the frozen V6 models.
        let v6Schema = Schema(versionedSchema: SchemaMigrationV6.self)
        let v6 = try ModelContainer(for: v6Schema, configurations: [ModelConfiguration(schema: v6Schema, url: copyA)])
        let oldTasks = try v6.mainContext.fetch(FetchDescriptor<SchemaMigrationV6.SchemaTask>())
        let oldLists = try v6.mainContext.fetch(FetchDescriptor<SchemaMigrationV6.SchemaList>())
        let oldBlocks = try v6.mainContext.fetch(FetchDescriptor<SchemaMigrationV6.SchemaBlock>())

        // B: the same store migrated with the full plan.
        let currentSchema = Schema(versionedSchema: SchemaCurrentVersion.self)
        let current = try ModelContainer(
            for: currentSchema,
            migrationPlan: SchemaAppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: currentSchema, url: copyB)]
        )
        let newTasks = try current.mainContext.fetch(FetchDescriptor<SchemaTask>())
        let newLists = try current.mainContext.fetch(FetchDescriptor<SchemaList>())
        let newBlocks = try current.mainContext.fetch(FetchDescriptor<SchemaBlock>())

        let tasksBefore = Set(oldTasks.map { "\($0.id)|\($0.title)|\($0.isCompleted)|\(String(describing: $0.completedAt))|\(String(describing: $0.list?.id))" })
        let tasksAfter = Set(newTasks.map { "\($0.id)|\($0.title)|\($0.isCompleted)|\(String(describing: $0.completedAt))|\(String(describing: $0.list?.id))" })
        let listsBefore = Set(oldLists.map { "\($0.id)|\($0.title)|\($0.order)|\($0.pageKindRaw)" })
        let listsAfter = Set(newLists.map { "\($0.id)|\($0.title)|\($0.order)|\($0.pageKindRaw)" })

        // Every line's text is in its owner's document, in order.
        func ownerKey(page: UUID?, task: UUID?) -> String { page.map { "p\($0)" } ?? task.map { "t\($0)" } ?? "-" }
        let linesByOwner = Dictionary(grouping: oldBlocks.filter { $0.page != nil || $0.task != nil }) { ownerKey(page: $0.page?.id, task: $0.task?.id) }
            .mapValues { $0.sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }.map(\.text).filter { !$0.isEmpty } }
        var textAfter: [String: [String]] = [:]
        for page in newLists where page.hasDocument { textAfter["p\(page.id)"] = page.documentText.components(separatedBy: "\n") }
        for task in newTasks where task.hasDocument { textAfter["t\(task.id)"] = task.documentText.components(separatedBy: "\n") }
        let textKept = linesByOwner.allSatisfy { key, lines in
            (textAfter[key] ?? []).joined(separator: "\n") == lines.joined(separator: "\n")
        }

        let linksBefore = Set(oldBlocks.compactMap(\.linkedTaskID))
        let linksAfter = Set(newLists.flatMap(\.linkedTaskIDs) + newTasks.flatMap(\.linkedTaskIDs))
        let todosBefore = oldBlocks.filter { $0.kindRaw == "todo" }
        let todosAfter = newLists.map(\.checklistCount).reduce(0, +) + newTasks.map(\.checklistCount).reduce(0, +)
        let doneAfter = newLists.map(\.checklistDoneCount).reduce(0, +) + newTasks.map(\.checklistDoneCount).reduce(0, +)

        let checks: [(String, Bool)] = [
            ("task count matches (\(oldTasks.count) → \(newTasks.count))", oldTasks.count == newTasks.count),
            ("page count matches (\(oldLists.count) → \(newLists.count))", oldLists.count == newLists.count),
            ("id, title, done state, completedAt and page unchanged for every task", tasksBefore == tasksAfter),
            ("id, title, order and kind unchanged for every page", listsBefore == listsAfter),
            ("every line's text kept, in order (\(oldBlocks.count) lines in \(linesByOwner.count) pages and tasks)", textKept),
            ("every to-do kept (\(todosBefore.count) → \(todosAfter)), ticks too", todosBefore.count == todosAfter && todosBefore.count { $0.isChecked } == doneAfter),
            ("every to-do keeps its task (\(linksBefore.count) links)", linksBefore == linksAfter),
            ("no lines left (\(newBlocks.count))", newBlocks.isEmpty),
        ]
        let lines = checks.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0)" }
        let ok = checks.allSatisfy(\.1)
        return (["MIGRATION SELFTEST \(ok ? "PASSED" : "FAILED")",
                 "completed tasks: \(oldTasks.filter(\.isCompleted).count)"] + lines).joined(separator: "\n")
    }
}
#endif

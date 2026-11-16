//
//  MigrationSelfTest.swift
//  Schema
//
//  DEBUG only. With SCHEMA_MIGRATION_SELFTEST=1 the app copies its own
//  store twice inside its container, reads copy A as V5 (no migration) and
//  migrates copy B to the current schema (V6), prints a comparison to
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

        // A: the store as it is today, read with the frozen V5 models.
        let v5Schema = Schema(versionedSchema: SchemaMigrationV5.self)
        let v5 = try ModelContainer(for: v5Schema, configurations: [ModelConfiguration(schema: v5Schema, url: copyA)])
        let oldTasks = try v5.mainContext.fetch(FetchDescriptor<SchemaMigrationV5.SchemaTask>())
        let oldLists = try v5.mainContext.fetch(FetchDescriptor<SchemaMigrationV5.SchemaList>())

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
        let listsBefore = Set(oldLists.map { "\($0.id)|\($0.title)|\($0.order)" })
        let listsAfter = Set(newLists.map { "\($0.id)|\($0.title)|\($0.order)" })
        let checks: [(String, Bool)] = [
            ("task count matches (\(oldTasks.count) → \(newTasks.count))", oldTasks.count == newTasks.count),
            ("page count matches (\(oldLists.count) → \(newLists.count))", oldLists.count == newLists.count),
            ("id, title, done state, completedAt and page unchanged for every task", tasksBefore == tasksAfter),
            ("id, title and order unchanged for every page", listsBefore == listsAfter),
            ("every page is a to-do list", newLists.allSatisfy { $0.pageKind == .todo }),
            ("no blocks yet (\(newBlocks.count))", newBlocks.isEmpty),
        ]
        let lines = checks.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0)" }
        let ok = checks.allSatisfy(\.1)
        return (["MIGRATION SELFTEST \(ok ? "PASSED" : "FAILED")",
                 "completed tasks: \(oldTasks.filter(\.isCompleted).count)"] + lines).joined(separator: "\n")
    }
}
#endif

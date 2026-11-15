//
//  MigrationSelfTest.swift
//  Schema
//
//  DEBUG only. With SCHEMA_MIGRATION_SELFTEST=1 the app copies its own
//  store twice inside its container, reads copy A as V4 (no migration) and
//  migrates copy B to V5, prints a comparison to stdout and exits. The real
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

        // A: the store as it is today, read with the frozen V4 models.
        let v4Schema = Schema(versionedSchema: SchemaMigrationV4.self)
        let v4 = try ModelContainer(for: v4Schema, configurations: [ModelConfiguration(schema: v4Schema, url: copyA)])
        let v4Tasks = try v4.mainContext.fetch(FetchDescriptor<SchemaMigrationV4.SchemaTask>())
        let v4Lists = try v4.mainContext.fetch(FetchDescriptor<SchemaMigrationV4.SchemaList>())

        // B: the same store migrated with the full plan.
        let v5Schema = Schema(versionedSchema: SchemaMigrationV5.self)
        let v5 = try ModelContainer(
            for: v5Schema,
            migrationPlan: SchemaAppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: v5Schema, url: copyB)]
        )
        let v5Tasks = try v5.mainContext.fetch(FetchDescriptor<SchemaTask>())
        let v5Lists = try v5.mainContext.fetch(FetchDescriptor<SchemaList>())

        let titlesBefore = Set(v4Tasks.map { "\($0.id)|\($0.title)|\($0.isCompleted)" })
        let titlesAfter = Set(v5Tasks.map { "\($0.id)|\($0.title)|\($0.isCompleted)" })
        let checks: [(String, Bool)] = [
            ("task count matches (\(v4Tasks.count) → \(v5Tasks.count))", v4Tasks.count == v5Tasks.count),
            ("list count matches (\(v4Lists.count) → \(v5Lists.count))", v4Lists.count == v5Lists.count),
            ("id, title and done state unchanged for every task", titlesBefore == titlesAfter),
            ("completedAt empty on every migrated task", v5Tasks.allSatisfy { $0.completedAt == nil }),
        ]
        let lines = checks.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0)" }
        let ok = checks.allSatisfy(\.1)
        return (["MIGRATION SELFTEST \(ok ? "PASSED" : "FAILED")",
                 "completed tasks: \(v4Tasks.filter(\.isCompleted).count)"] + lines).joined(separator: "\n")
    }
}
#endif

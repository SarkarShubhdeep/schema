//
//  ModelContainerFactory.swift
//  Schema
//

import Foundation
import SwiftData

struct ModelContainerError: LocalizedError, Equatable {
    let message: String

    var errorDescription: String? { message }
}

enum ModelContainerLoadState: Equatable {
    case loading
    case ready
    case failed(ModelContainerError)
}

@MainActor
enum ModelContainerFactory {
    static func storeURL() -> URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.sarkarshubhdeep.schema"
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent(bundleID, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("Schema.store")
    }

    static func makeContainer(resetStore: Bool = false) -> Result<ModelContainer, ModelContainerError> {
        if resetStore {
            deleteStore(at: storeURL())
        }

        do {
            let schema = Schema(versionedSchema: SchemaMigrationV4.self)
            let configuration = ModelConfiguration(schema: schema, url: storeURL())
            let container = try ModelContainer(
                for: schema,
                migrationPlan: SchemaAppMigrationPlan.self,
                configurations: [configuration]
            )
            return .success(container)
        } catch {
            return .failure(ModelContainerError(message: error.localizedDescription))
        }
    }

    static func deleteStore(at url: URL) {
        let relatedPaths = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm"),
        ]

        for path in relatedPaths {
            try? FileManager.default.removeItem(at: path)
        }
    }
}

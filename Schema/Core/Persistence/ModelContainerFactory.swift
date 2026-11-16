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

    /// True while the app hosts the unit tests. The tests then get an empty
    /// in-memory store, so running them never opens or migrates real data.
    static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func makeContainer(resetStore: Bool = false) -> Result<ModelContainer, ModelContainerError> {
        if isHostingTests {
            do {
                let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return .success(try ModelContainer(for: schema, configurations: [configuration]))
            } catch {
                return .failure(ModelContainerError(message: error.localizedDescription))
            }
        }

        #if DEBUG
        if DemoData.isEnabled {
            do {
                return .success(try DemoData.makeContainer())
            } catch {
                return .failure(ModelContainerError(message: error.localizedDescription))
            }
        }
        #endif

        if resetStore {
            deleteStore(at: storeURL())
        }

        do {
            let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
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

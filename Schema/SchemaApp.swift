//
//  SchemaApp.swift
//  Schema
//

import SwiftUI
import SwiftData

@main
struct SchemaApp: App {
    var modelContainer: ModelContainer = {
        let schema = Schema([SchemaList.self, SchemaTask.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Text("Schema")
                .font(.largeTitle)
                .frame(minWidth: 400, minHeight: 300)
        }
        .modelContainer(modelContainer)
    }
}

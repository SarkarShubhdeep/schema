//
//  SchemaApp.swift
//  Schema
//

import SwiftUI
import SwiftData

@main
struct SchemaApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var loadError: ModelContainerError?
    @State private var showResetConfirmation = false

    init() {
#if os(macOS)
        NotificationHandler.shared.configure()
#endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer {
                    ContentView()
                        .modelContainer(modelContainer)
                } else if let loadError {
                    ModelContainerErrorView(
                        error: loadError,
                        onRetry: { loadModelContainer(resetStore: false) },
                        onResetStore: { showResetConfirmation = true }
                    )
                } else {
                    ProgressView("Loading Schema…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(SchemaTheme.background)
                }
            }
            .onAppear {
                if modelContainer == nil, loadError == nil {
                    loadModelContainer(resetStore: false)
                }
            }
            .confirmationDialog(
                "Reset local data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset and Start Fresh", role: .destructive) {
                    loadModelContainer(resetStore: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all lists and tasks stored on this Mac and cannot be undone.")
            }
        }
        .defaultSize(width: 900, height: 640)
    }

    private func loadModelContainer(resetStore: Bool) {
        switch ModelContainerFactory.makeContainer(resetStore: resetStore) {
        case .success(let container):
            modelContainer = container
            loadError = nil
        case .failure(let error):
            modelContainer = nil
            loadError = error
        }
    }
}

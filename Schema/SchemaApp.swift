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
        SchemaFont.registerBundledFonts()
#if os(macOS)
        NotificationHandler.shared.configure()
#endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ComponentGallery.isEnabled {
                    ComponentGalleryView()
                } else {
                    appContent
                }
                #else
                appContent
                #endif
            }
            .onAppear {
                #if DEBUG && os(macOS)
                if DemoData.forcesDarkAppearance {
                    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                }
                if DemoData.isEnabled, let window = NSApplication.shared.windows.first {
                    // Screenshots always use the design's window size, not the last saved frame.
                    window.setContentSize(NSSize(width: 1280, height: 800))
                    window.center()
                }
                #endif
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
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
    }

    @ViewBuilder
    private var appContent: some View {
        if let modelContainer {
            ContentView()
                .font(.schemaBody)
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
                .background(SchemaTheme.canvas)
        }
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

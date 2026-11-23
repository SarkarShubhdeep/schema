//
//  SettingsScreen.swift
//  Schema
//
//  The whole window while Settings is open (#108): its own sidebar and the
//  section page. ⌘F goes to search; Esc clears a search, then goes back.
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(WorkspaceState.self) private var workspace
    @Bindable var listViewModel: ListViewModel
    let lists: [SchemaList]
    let notificationService: any NotificationServiceProtocol

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(isSearchFocused: $isSearchFocused)
            SettingsPage(listViewModel: listViewModel, lists: lists, notificationService: notificationService)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(SchemaTheme.canvas.ignoresSafeArea())
        .background {
            // ⌘F from anywhere on the page.
            Button("Search settings") { isSearchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
                .accessibilityHidden(true)
        }
        .onExitCommand(perform: escape)
        .onKeyPress(.escape) {
            escape()
            return .handled
        }
        .onAppear {
            #if DEBUG
            if DemoData.isEnabled, let query = DemoData.settingsQuery {
                workspace.settingsQuery = query
            }
            #endif
        }
    }

    private func escape() {
        if !workspace.settingsQuery.isEmpty {
            workspace.settingsQuery = ""
        } else if isSearchFocused {
            isSearchFocused = false
        } else {
            workspace.showSettings = false
        }
    }
}

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
        HStack(spacing: ShellMetrics.margin) {
            SettingsSidebar(isSearchFocused: $isSearchFocused)
            VStack(spacing: ShellMetrics.margin) {
                HeaderIsland {
                    Text("Settings")
                    Text("/").foregroundStyle(SchemaTheme.inkFaint)
                    Text(workspace.settingsQuery.isEmpty ? workspace.settingsSection.title : "Search")
                        .foregroundStyle(SchemaTheme.ink)
                } trailing: {
                    EmptyView()
                }
                SettingsPage(listViewModel: listViewModel, lists: lists, notificationService: notificationService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(ShellMetrics.margin)
        .background(SchemaTheme.canvas)
        .ignoresSafeArea()
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

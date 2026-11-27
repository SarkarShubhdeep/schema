//
//  PanelCommands.swift
//  Schema
//
//  View menu items for the side panels: ⌘⌥← toggles the sidebar,
//  ⌘⌥→ toggles the details panel.
//

import AppKit
import SwiftUI

extension FocusedValues {
    @Entry var workspaceState: WorkspaceState?
}

struct PanelCommands: Commands {
    @FocusedValue(\.workspaceState) private var workspace

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button(workspace?.isSidebarCollapsed == true ? "Expand Sidebar" : "Collapse Sidebar") {
                workspace?.toggleSidebar()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(workspace == nil)

            Button(workspace?.isDetailsPanelCollapsed == true ? "Expand Details Panel" : "Collapse Details Panel") {
                workspace?.toggleDetailsPanel()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(workspace == nil)

            Divider()
        }

        // Back and forward through the places you've been (#118).
        CommandMenu("Go") {
            Button("Search Everything\u{2026}") { workspace?.openCommandBar() }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(workspace == nil)
            Button("Commands\u{2026}") { workspace?.openCommandBar(commandsOnly: true) }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(workspace == nil)
            Divider()
            Button("Back") { workspace?.navigation.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(workspace?.navigation.canGoBack != true)
            Button("Forward") { workspace?.navigation.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(workspace?.navigation.canGoForward != true)
            Divider()
            ForEach(ViewKind.allCases, id: \.self) { kind in
                Button(kind.title) { workspace?.navigation.go(to: .view(kind)) }
                    .disabled(workspace == nil)
            }
            Button(ToolKind.pomodoro.title) { workspace?.navigation.go(to: .tool(.pomodoro)) }
                .disabled(workspace == nil)
        }
    }
}

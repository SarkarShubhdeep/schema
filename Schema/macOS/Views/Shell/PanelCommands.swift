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
    }
}

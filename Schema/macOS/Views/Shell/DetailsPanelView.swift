//
//  DetailsPanelView.swift
//  Schema
//
//  Right column of the window. It shows the overview (reminders, the week,
//  routines), or a task's cards while a task page is open (#31). Collapsed
//  (⌘⌥→) it is a 52pt strip of icons that open it again.
//

import SwiftUI

struct PanelRailItem: Identifiable {
    let systemImage: String
    let label: String
    var id: String { label }
}

struct DetailsPanelView<Content: View>: View {
    @Environment(WorkspaceState.self) private var workspace

    /// "Overview" or "Task".
    let title: String
    /// Icons on the collapsed strip; each opens the panel.
    let railItems: [PanelRailItem]
    @ViewBuilder let content: () -> Content

    var body: some View {
        let isCollapsed = workspace.isDetailsPanelCollapsed

        ScrollView {
            if isCollapsed {
                VStack(spacing: 4) {
                    SchemaIconButton(systemImage: "sidebar.right", label: "Expand panel", shortcut: "⌘⌥→", size: 40) {
                        workspace.toggleDetailsPanel()
                    }
                    Rectangle()
                        .fill(SchemaTheme.line)
                        .frame(width: 24, height: 1)
                        .padding(.vertical, 6)
                    ForEach(railItems) { item in
                        SchemaIconButton(systemImage: item.systemImage, label: item.label, size: 40) {
                            workspace.toggleDetailsPanel()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SchemaSectionLabel(title)
                        Spacer(minLength: 8)
                        SchemaIconButton(systemImage: "sidebar.right", label: "Collapse panel", shortcut: "⌘⌥→", size: 28) {
                            workspace.toggleDetailsPanel()
                        }
                    }
                    content()
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.top, 14)
                .padding(.bottom, 24)
                .frame(width: ShellMetrics.detailsWidth, alignment: .leading)
                .transition(.opacity)
            }
        }
        .scrollIndicators(.automatic)
        .frame(width: isCollapsed ? ShellMetrics.detailsRailWidth : ShellMetrics.detailsWidth)
        .frame(maxHeight: .infinity)
        .clipped()
        .background(SchemaTheme.canvas.ignoresSafeArea())
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }
}

/// The details panel sits inside the workspace, below the hidden title bar.
/// This strip, drawn from the window root, continues the panel's fill and
/// divider up to the top edge of the window. It is decoration only.
struct DetailsPanelTitleBarStrip: View {
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        let width = workspace.isDetailsPanelCollapsed ? ShellMetrics.detailsRailWidth : ShellMetrics.detailsWidth

        VStack(spacing: 0) {
            SchemaTheme.canvas
                // Overlaps the panel by a few points so no seam shows; the
                // panel's content starts lower than that.
                .frame(width: width, height: ShellMetrics.titleBarHeight + 8)
                .overlay(alignment: .leading) {
                    Rectangle().fill(SchemaTheme.line).frame(width: 1)
                }
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(.container, edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

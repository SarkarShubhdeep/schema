//
//  DetailsPanelView.swift
//  Schema
//
//  Right column of the window. With a task open it shows that task's
//  editor (360pt, on the surface colour), opening even if the panel was
//  collapsed; closing the task returns the panel to its saved state.
//  Otherwise it is an empty state, or a 52pt rail when collapsed (⌘⌥→).
//

import SwiftUI

struct DetailsPanelView<Detail: View, Overview: View>: View {
    @Environment(WorkspaceState.self) private var workspace

    /// The open task's editor, if any.
    let detail: Detail?
    let onCloseDetail: () -> Void
    /// Shown when no task is open: reminders, the week, routines.
    let overview: Overview

    var body: some View {
        let showsDetail = detail != nil
        let isCollapsed = workspace.isDetailsPanelCollapsed && !showsDetail

        ScrollView {
            if let detail {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        SchemaSectionLabel("Task")
                        Spacer(minLength: 8)
                        SchemaIconButton(systemImage: "xmark", label: "Close", shortcut: "Esc", size: 28, action: onCloseDetail)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    detail
                }
                .frame(width: ShellMetrics.detailsTaskWidth, alignment: .leading)
                .transition(.opacity)
            } else if isCollapsed {
                VStack(spacing: 4) {
                    SchemaIconButton(systemImage: "sidebar.right", label: "Expand panel", shortcut: "⌘⌥→", size: 40) {
                        workspace.toggleDetailsPanel()
                    }
                    Rectangle()
                        .fill(SchemaTheme.line)
                        .frame(width: 24, height: 1)
                        .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SchemaSectionLabel("Overview")
                        Spacer(minLength: 8)
                        SchemaIconButton(systemImage: "sidebar.right", label: "Collapse panel", shortcut: "⌘⌥→", size: 28) {
                            workspace.toggleDetailsPanel()
                        }
                    }
                    overview
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
        .frame(width: showsDetail
               ? ShellMetrics.detailsTaskWidth
               : (isCollapsed ? ShellMetrics.detailsRailWidth : ShellMetrics.detailsWidth))
        .frame(maxHeight: .infinity)
        .clipped()
        .background((showsDetail ? SchemaTheme.surface : SchemaTheme.canvas).ignoresSafeArea())
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
        let isOpen = workspace.isDetailOpen
        let width = isOpen
            ? ShellMetrics.detailsTaskWidth
            : (workspace.isDetailsPanelCollapsed ? ShellMetrics.detailsRailWidth : ShellMetrics.detailsWidth)

        VStack(spacing: 0) {
            (isOpen ? SchemaTheme.surface : SchemaTheme.canvas)
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

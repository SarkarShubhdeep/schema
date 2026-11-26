//
//  DetailsPanelView.swift
//  Schema
//
//  The details panel island on the right (#116), 283pt wide: a header row
//  with the collapse button and the panel's name, then the overview
//  (reminders, the week, routines) or a task's cards while a task page is
//  open (#31). Collapsed (⌘⌥→) it is just its expand button,
//  DetailsPanelPill.
//

import SwiftUI

struct DetailsPanelView<Content: View>: View {
    @Environment(WorkspaceState.self) private var workspace

    /// "Overview" or "Task".
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ShellMetrics.innerGap) {
            HStack(spacing: ShellMetrics.innerGap) {
                IslandIconButton(systemImage: "sidebar.right", label: "Hide \(title.lowercased())", shortcut: "⌘⌥→") {
                    workspace.toggleDetailsPanel()
                }
                SchemaSectionLabel(title)
                    .padding(.leading, 4)
                Spacer(minLength: 0)
            }
            .frame(height: ShellMetrics.control)

            ScrollView {
                VStack(alignment: .leading, spacing: ShellMetrics.innerGap) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: .infinity)
        }
        .frame(width: ShellMetrics.detailsWidth - ShellMetrics.islandPadding * 2)
        .frame(maxHeight: .infinity)
        .shellIsland()
    }
}

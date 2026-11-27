//
//  DetailsPanelView.swift
//  Schema
//
//  The details panel island on the right (#116), 283pt wide and only as
//  tall as what it shows (it scrolls past the window's height): a header row
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

    /// Height of the panel's content, so the island hugs it (#116).
    @State private var contentHeight: CGFloat = 400

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
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .themedScrollBars()
            }
            .scrollIndicators(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            // As tall as what's in it; it scrolls once that's taller than the window.
            .frame(maxHeight: contentHeight)
        }
        .frame(width: ShellMetrics.detailsWidth - ShellMetrics.islandPadding * 2)
        .shellIsland()
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

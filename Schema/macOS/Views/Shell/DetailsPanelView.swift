//
//  DetailsPanelView.swift
//  Schema
//
//  Right column of the window. It scrolls on its own and collapses to a 52pt
//  rail with ⌘⌥→. The day overview and task details move in with later
//  issues, so for now it shows a quiet empty state.
//

import SwiftUI

struct DetailsPanelView: View {
    @Environment(WorkspaceState.self) private var workspace

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
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SchemaSectionLabel("Details")
                        Spacer(minLength: 8)
                        SchemaIconButton(systemImage: "sidebar.right", label: "Collapse panel", shortcut: "⌘⌥→", size: 28) {
                            workspace.toggleDetailsPanel()
                        }
                    }
                    Text("Select a task to see its details here.")
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 20)
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

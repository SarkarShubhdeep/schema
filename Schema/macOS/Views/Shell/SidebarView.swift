//
//  SidebarView.swift
//  Schema
//
//  The sidebar island (#116), 283pt wide: a header row with the window
//  controls and the collapse button, the views, pages and tags (they
//  scroll), and a footer row with Settings and Notifications. ⌘⌥←
//  collapses it to SidebarPill.
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let onNotificationSelect: (SchemaNotificationItem) -> Void

    var body: some View {
        VStack(spacing: ShellMetrics.innerGap) {
            HStack(spacing: ShellMetrics.innerGap) {
                // The window controls sit here (WindowControlsPlacement).
                Color.clear
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                IslandIconButton(systemImage: "sidebar.left", label: "Collapse sidebar", shortcut: "⌘⌥←") {
                    workspace.toggleSidebar()
                }
            }
            .frame(height: ShellMetrics.control)

            ScrollView {
                SidebarNavigation(lists: lists, allTasks: allTasks, listViewModel: listViewModel)
                    .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            .frame(maxHeight: .infinity)

            HStack(spacing: ShellMetrics.innerGap) {
                IslandIconButton(systemImage: "gearshape", label: "Settings", shortcut: "⌘,") {
                    workspace.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
                notificationsRow
            }
            .frame(height: ShellMetrics.control)
        }
        .frame(width: ShellMetrics.sidebarWidth - ShellMetrics.islandPadding * 2)
        .frame(maxHeight: .infinity)
        .shellIsland()
    }

    private var notificationsRow: some View {
        @Bindable var workspace = workspace
        let pending = workspace.notificationItems.count

        return SidebarRow(
            title: "Notifications",
            isActive: false,
            trailing: .count(pending),
            tooltip: "Notifications"
        ) {
            Image(systemName: "bell")
                .overlay(alignment: .topTrailing) {
                    if pending > 0 {
                        Circle()
                            .fill(SchemaTheme.ink)
                            .frame(width: 5, height: 5)
                            .offset(x: 2, y: -1)
                    }
                }
        } action: {
            workspace.showNotifications.toggle()
        }
        .frame(height: ShellMetrics.control)
        .popover(isPresented: $workspace.showNotifications, arrowEdge: .trailing) {
            NotificationsPopover(items: workspace.notificationItems, onSelect: onNotificationSelect)
        }
        .accessibilityValue(pending == 0 ? "" : "\(pending) pending")
    }
}

/// The collapsed sidebar (#116): a 150pt pill at the top left that holds
/// the window controls and the expand button, nothing else.
struct SidebarPill: View {
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        HStack(spacing: ShellMetrics.innerGap) {
            Color.clear
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            IslandIconButton(systemImage: "sidebar.left", label: "Expand sidebar", shortcut: "⌘⌥←") {
                workspace.toggleSidebar()
            }
        }
        .frame(width: ShellMetrics.collapsedSidebarWidth - ShellMetrics.islandPadding * 2, height: ShellMetrics.control)
        .shellIsland()
    }
}

/// The collapsed details panel (#116): its expand button at the top right.
struct DetailsPanelPill: View {
    @Environment(WorkspaceState.self) private var workspace

    let title: String

    var body: some View {
        IslandIconButton(systemImage: "sidebar.right", label: "Show \(title.lowercased())", shortcut: "⌘⌥→") {
            workspace.toggleDetailsPanel()
        }
        .shellIsland()
    }
}

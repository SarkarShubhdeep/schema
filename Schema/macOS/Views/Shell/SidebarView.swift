//
//  SidebarView.swift
//  Schema
//
//  Left column of the window. The window controls sit at its top (the title
//  bar is hidden). Open it is 240pt; collapsed it is a 72pt rail of icons.
//  ⌘⌥← toggles it. Only the width animates (see SidebarRow).
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let onNotificationSelect: (SchemaNotificationItem) -> Void

    var body: some View {
        let isCollapsed = workspace.isSidebarCollapsed

        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                header(isCollapsed: isCollapsed)

                SidebarNavigation(lists: lists, allTasks: allTasks, listViewModel: listViewModel, isCollapsed: isCollapsed)

                SidebarSectionHeader(title: "", isCollapsed: true)
                    .opacity(isCollapsed ? 1 : 0)
                notificationsRow(isCollapsed: isCollapsed)
                settingsRow(isCollapsed: isCollapsed)
            }
            .padding(.horizontal, SidebarMetrics.rowInset(collapsed: isCollapsed))
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
        .frame(width: isCollapsed ? ShellMetrics.sidebarRailWidth : ShellMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .clipped()
        .background(SchemaTheme.surfaceSunken.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            SchemaIconButton(systemImage: "sidebar.left", label: "Collapse sidebar", shortcut: "⌘⌥←", size: 28) {
                workspace.toggleSidebar()
            }
            .padding(.trailing, 12)
            .offset(y: ShellMetrics.windowControlsCenterY - 14)
            .ignoresSafeArea()
            .opacity(isCollapsed ? 0 : 1)
            .allowsHitTesting(!isCollapsed)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    /// Open: the wordmark. Collapsed: the expand button, in the same slot.
    private func header(isCollapsed: Bool) -> some View {
        ZStack(alignment: .leading) {
            Text("Schema")
                .font(.spaceGrotesk(19, weight: .bold, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(SchemaTheme.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, 12)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .clipped()
                .opacity(isCollapsed ? 0 : 1)

            SchemaIconButton(systemImage: "sidebar.left", label: "Expand sidebar", shortcut: "⌘⌥←", size: SidebarMetrics.rowHeight) {
                workspace.toggleSidebar()
            }
            .opacity(isCollapsed ? 1 : 0)
            .allowsHitTesting(isCollapsed)
        }
        .frame(height: SidebarMetrics.rowHeight)
        .padding(.bottom, 2)
    }

    private func settingsRow(isCollapsed: Bool) -> some View {
        SidebarRow(
            title: "Settings",
            isActive: false,
            isCollapsed: isCollapsed,
            trailing: .keys("⌘,"),
            tooltip: "Settings  ⌘,"
        ) {
            Image(systemName: "gearshape")
        } action: {
            workspace.showSettings = true
        }
        .keyboardShortcut(",", modifiers: .command)
    }

    private func notificationsRow(isCollapsed: Bool) -> some View {
        @Bindable var workspace = workspace
        let pending = workspace.notificationItems.count

        return SidebarRow(
            title: "Notifications",
            isActive: false,
            isCollapsed: isCollapsed,
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
        .popover(isPresented: $workspace.showNotifications, arrowEdge: .trailing) {
            NotificationsPopover(items: workspace.notificationItems, onSelect: onNotificationSelect)
        }
        .accessibilityValue(pending == 0 ? "" : "\(pending) pending")
    }
}

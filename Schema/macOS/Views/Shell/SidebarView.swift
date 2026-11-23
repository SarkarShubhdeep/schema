//
//  SidebarView.swift
//  Schema
//
//  Left column of the window. The window controls sit at its top (the title
//  bar is hidden). It is 240pt wide; ⌘⌥← collapses it, and the floating bar
//  (FloatingSidebarBar) takes its place.
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let onNotificationSelect: (SchemaNotificationItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schema")
                    .font(.spaceGrotesk(19, weight: .bold, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(1)
                    .padding(.leading, 12)
                    .frame(height: SidebarMetrics.rowHeight)
                    .padding(.bottom, 2)

                SidebarNavigation(lists: lists, allTasks: allTasks, listViewModel: listViewModel)

                Color.clear.frame(height: 36)
                notificationsRow
                settingsRow
            }
            .padding(.horizontal, SidebarMetrics.rowInset)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
        .frame(width: ShellMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(SchemaTheme.surfaceSunken.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            SchemaIconButton(systemImage: "sidebar.left", label: "Collapse sidebar", shortcut: "⌘⌥←", size: 28) {
                workspace.toggleSidebar()
            }
            .padding(.trailing, 12)
            .offset(y: ShellMetrics.windowControlsCenterY - 14)
            .ignoresSafeArea()
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    private var settingsRow: some View {
        SidebarRow(
            title: "Settings",
            isActive: false,
            trailing: .keys("⌘,"),
            tooltip: "Settings  ⌘,"
        ) {
            Image(systemName: "gearshape")
        } action: {
            workspace.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
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
        .popover(isPresented: $workspace.showNotifications, arrowEdge: .trailing) {
            NotificationsPopover(items: workspace.notificationItems, onSelect: onNotificationSelect)
        }
        .accessibilityValue(pending == 0 ? "" : "\(pending) pending")
    }
}

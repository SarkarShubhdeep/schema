//
//  SidebarView.swift
//  Schema
//
//  Left column of the window. The window controls sit at its top (the title
//  bar is hidden). Expanded it is 240pt with the wordmark; collapsed it is a
//  72pt rail of icons. ⌘⌥← toggles it.
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
            Group {
                if isCollapsed {
                    rail
                } else {
                    expanded
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
        .frame(width: isCollapsed ? ShellMetrics.sidebarRailWidth : ShellMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(SchemaTheme.surfaceSunken.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if !isCollapsed {
                SchemaIconButton(systemImage: "sidebar.left", label: "Collapse sidebar", shortcut: "⌘⌥←", size: 28) {
                    workspace.toggleSidebar()
                }
                .padding(.trailing, 12)
                .offset(y: ShellMetrics.windowControlsCenterY - 14)
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text("Schema")
                    .font(.spaceGrotesk(19, weight: .bold, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 8)
                notificationsButton
                settingsButton
            }
            .padding(.leading, 12)
            .padding(.bottom, 10)

            SidebarNavigation(lists: lists, allTasks: allTasks, listViewModel: listViewModel, isRail: false)
        }
        .padding(.horizontal, 12)
        .transition(.opacity)
    }

    private var rail: some View {
        VStack(spacing: 4) {
            SchemaIconButton(systemImage: "sidebar.left", label: "Expand sidebar", shortcut: "⌘⌥←", size: 40) {
                workspace.toggleSidebar()
            }
            railDivider
            SidebarNavigation(lists: lists, allTasks: allTasks, listViewModel: listViewModel, isRail: true)
            railDivider
            notificationsButton
            settingsButton
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private var railDivider: some View {
        Rectangle()
            .fill(SchemaTheme.line)
            .frame(width: 28, height: 1)
            .padding(.vertical, 6)
    }

    private var buttonSize: CGFloat { workspace.isSidebarCollapsed ? 40 : 32 }

    private var settingsButton: some View {
        SchemaIconButton(systemImage: "gearshape", label: "Settings", shortcut: "⌘,", size: buttonSize) {
            workspace.showSettings = true
        }
        .keyboardShortcut(",", modifiers: .command)
    }

    private var notificationsButton: some View {
        @Bindable var workspace = workspace

        return SchemaIconButton(systemImage: "bell", label: "Notifications", size: buttonSize) {
            workspace.showNotifications.toggle()
        }
        .overlay(alignment: .topTrailing) {
            if !workspace.notificationItems.isEmpty {
                Circle()
                    .fill(SchemaTheme.ink)
                    .frame(width: 6, height: 6)
                    .offset(x: -buttonSize / 4, y: buttonSize / 4)
                    .allowsHitTesting(false)
            }
        }
        .popover(isPresented: $workspace.showNotifications, arrowEdge: .bottom) {
            NotificationsPopover(items: workspace.notificationItems, onSelect: onNotificationSelect)
        }
        .accessibilityValue(workspace.notificationItems.isEmpty ? "" : "\(workspace.notificationItems.count) pending")
    }
}

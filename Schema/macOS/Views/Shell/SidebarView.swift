//
//  SidebarView.swift
//  Schema
//
//  Left column of the window. The window controls sit at its top (the title
//  bar is hidden), followed by the wordmark, notifications and settings.
//  Navigation arrives with #12.
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) private var workspace

    let onNotificationSelect: (SchemaNotificationItem) -> Void

    var body: some View {
        @Bindable var workspace = workspace

        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text("Schema")
                        .font(.spaceGrotesk(19, weight: .bold, relativeTo: .title3))
                        .tracking(-0.4)
                        .foregroundStyle(SchemaTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    notificationsButton
                    SchemaIconButton(systemImage: "gearshape", label: "Settings", shortcut: "⌘,") {
                        workspace.showSettings = true
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
                .padding(.leading, 12)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
        .frame(width: ShellMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(SchemaTheme.surfaceSunken.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }

    private var notificationsButton: some View {
        @Bindable var workspace = workspace

        return SchemaIconButton(systemImage: "bell", label: "Notifications") {
            workspace.showNotifications.toggle()
        }
        .overlay(alignment: .topTrailing) {
            if !workspace.notificationItems.isEmpty {
                Circle()
                    .fill(SchemaTheme.ink)
                    .frame(width: 6, height: 6)
                    .offset(x: -8, y: 8)
                    .allowsHitTesting(false)
            }
        }
        .popover(isPresented: $workspace.showNotifications, arrowEdge: .bottom) {
            NotificationsPopover(items: workspace.notificationItems, onSelect: onNotificationSelect)
        }
        .accessibilityValue(workspace.notificationItems.isEmpty ? "" : "\(workspace.notificationItems.count) pending")
    }
}

/// Fixed column widths from the dashboard design.
enum ShellMetrics {
    static let sidebarWidth: CGFloat = 240
    static let detailsWidth: CGFloat = 300
    static let mainMinWidth: CGFloat = 420
    /// Until panels can collapse (#10, #11), the window can't get narrower than all three columns.
    static let minimumWindowWidth: CGFloat = sidebarWidth + mainMinWidth + detailsWidth
}

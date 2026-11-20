//
//  FloatingSidebarBar.swift
//  Schema
//
//  The collapsed sidebar (#43): a narrow floating capsule over the main
//  column, under the window controls. It holds only the expand button, the
//  views, New page, Notifications and Settings; pages stay in the open
//  sidebar. If the window is too short it scrolls, without a scroll bar.
//

import SwiftUI

struct FloatingSidebarBar: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let listViewModel: ListViewModel
    let onNotificationSelect: (SchemaNotificationItem) -> Void

    /// Top of the bar, measured from the window top: clear of the window controls.
    static let topInset: CGFloat = 52

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                FloatingBarButton(systemImage: "sidebar.left", label: "Expand sidebar", shortcut: "⌘⌥←") {
                    workspace.toggleSidebar()
                }
                divider

                ForEach(SmartView.allCases) { view in
                    FloatingBarButton(
                        systemImage: view.systemImage,
                        label: view.title,
                        isActive: listViewModel.smartView == view
                    ) {
                        listViewModel.selectSmartView(view, from: lists)
                    }
                }
                FloatingBarButton(
                    systemImage: "tray.full",
                    label: SchemaList.everythingTitle,
                    shortcut: "/",
                    isActive: isEverythingActive
                ) {
                    listViewModel.selectEverythingList(from: lists)
                }
                FloatingBarButton(
                    systemImage: "timer",
                    label: "Pomodoro",
                    isActive: listViewModel.showsPomodoro
                ) {
                    listViewModel.selectPomodoro(from: lists)
                }
                FloatingBarButton(systemImage: "plus", label: "New page", shortcut: "⌘N") {
                    listViewModel.openNewPage()
                }
                divider

                notificationsButton
                FloatingBarButton(systemImage: "gearshape", label: "Settings", shortcut: "⌘,") {
                    workspace.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(4)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: ShellMetrics.floatingBarWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            Capsule(style: .continuous)
                .fill(SchemaTheme.surface)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
        .clipShape(Capsule(style: .continuous))
        .padding(.leading, ShellMetrics.floatingBarEdgeInset)
        .padding(.top, Self.topInset)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar, collapsed")
    }

    private var divider: some View {
        Rectangle()
            .fill(SchemaTheme.line)
            .frame(width: 24, height: 1)
            .padding(.vertical, 4)
    }

    private var notificationsButton: some View {
        @Bindable var workspace = workspace
        let pending = workspace.notificationItems.count

        return FloatingBarButton(systemImage: "bell", label: "Notifications", hasDot: pending > 0) {
            workspace.showNotifications.toggle()
        }
        .popover(isPresented: $workspace.showNotifications, arrowEdge: .trailing) {
            NotificationsPopover(items: workspace.notificationItems, onSelect: onNotificationSelect)
        }
        .accessibilityValue(pending == 0 ? "" : "\(pending) pending")
    }

    private var isEverythingActive: Bool {
        listViewModel.smartView == nil && !listViewModel.showsPomodoro
            && listViewModel.selectedList(from: lists)?.isEverythingList == true
    }
}

/// A 40pt round icon button in the floating bar. The active view is filled.
private struct FloatingBarButton: View {
    let systemImage: String
    let label: String
    var shortcut: String?
    var isActive = false
    var hasDot = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .overlay(alignment: .topTrailing) {
                    if hasDot {
                        Circle()
                            .fill(SchemaTheme.ink)
                            .frame(width: 5, height: 5)
                            .offset(x: 2, y: -1)
                    }
                }
                .foregroundStyle(isActive ? SchemaTheme.canvas : (isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted))
                .frame(width: 40, height: 40)
                .background(Circle().fill(isActive ? SchemaTheme.ink : (isHovered ? SchemaTheme.surfaceHover : .clear)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help(shortcut.map { "\(label)  \($0)" } ?? label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

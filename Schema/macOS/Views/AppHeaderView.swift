//
//  AppHeaderView.swift
//  Schema
//

import SwiftUI

struct AppHeaderToolbar: ToolbarContent {
    @Binding var showNotifications: Bool
    @Binding var showSettings: Bool

    let pendingNotificationCount: Int
    let notificationItems: [SchemaNotificationItem]
    let onNotificationSelect: (SchemaNotificationItem) -> Void

    private enum Metrics {
        static let slotSize: CGFloat = 22
        static let symbolSize: CGFloat = 18
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showNotifications.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    toolbarSymbol("bell", size: Metrics.symbolSize)

                    if pendingNotificationCount > 0 {
                        Circle()
                            .fill(SchemaTheme.accent)
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: -3)
                    }
                }
                .frame(width: Metrics.slotSize, height: Metrics.slotSize)
            }
            .help("Notifications")
            .popover(isPresented: $showNotifications, arrowEdge: .top) {
                NotificationsPopover(items: notificationItems, onSelect: onNotificationSelect)
            }

            Button {
                showSettings = true
            } label: {
                toolbarSymbol("gearshape", size: Metrics.symbolSize)
                    .frame(width: Metrics.slotSize, height: Metrics.slotSize)
            }
            .help("Settings")
        }
    }

    private func toolbarSymbol(_ name: String, size: CGFloat) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(SchemaTheme.mutedText)
    }
}

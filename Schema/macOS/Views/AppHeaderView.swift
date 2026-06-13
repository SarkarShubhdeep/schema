//
//  AppHeaderView.swift
//  Schema
//

import SwiftUI

struct AppHeaderToolbar: ToolbarContent {
    @Binding var showNotifications: Bool
    @Binding var showSettings: Bool
    @Binding var showAccountAlert: Bool

    let pendingNotificationCount: Int
    let notificationItems: [SchemaNotificationItem]
    let onNotificationSelect: (SchemaNotificationItem) -> Void

    private enum Metrics {
        static let slotSize: CGFloat = 22
        static let symbolSize: CGFloat = 18
        static let accountSymbolSize: CGFloat = 22
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

            Menu {
                Button("Account") {}
                    .disabled(true)

                Divider()

                Button("Logout") {
                    showAccountAlert = true
                }
            } label: {
                toolbarSymbol("person.circle.fill", size: Metrics.accountSymbolSize)
                    .frame(width: Metrics.slotSize, height: Metrics.slotSize)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .help("Account")
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

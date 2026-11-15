//
//  NotificationsPopover.swift
//  Schema
//

import SwiftUI

struct NotificationsPopover: View {
    let items: [SchemaNotificationItem]
    let onSelect: (SchemaNotificationItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notifications")
                .font(.spaceGrotesk(13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            if items.isEmpty {
                Text("No upcoming reminders")
                    .font(.satoshi(13))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.satoshi(13, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                            .font(.satoshi(11))
                                            .foregroundStyle(SchemaTheme.inkMuted)
                                            .lineLimit(1)
                                    }

                                    Text(ReminderFormatting.displayString(for: item.fireDate))
                                        .font(.spaceGrotesk(11, weight: .medium).monospacedDigit())
                                        .foregroundStyle(SchemaTheme.inkMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if item.id != items.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 280)
    }
}

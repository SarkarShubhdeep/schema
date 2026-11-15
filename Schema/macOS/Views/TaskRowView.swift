//
//  TaskRowView.swift
//  Schema
//

import SwiftUI

struct TaskRowView: View {
    @Bindable var task: SchemaTask
    let isHighlighted: Bool
    let isKeyboardSelected: Bool
    let isSequenceBlocked: Bool
    let showListTag: Bool
    var isLifted: Bool = false
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSetReminder: (Date?) -> Void
    let onSelect: () -> Void
    let onDeselect: () -> Void
    let onOpenDetail: () -> Void

    @State private var showReminderPicker = false
    @State private var reminderDate = Date()
    @State private var isHovered = false

    private enum Metrics {
        static let reminderColumnWidth: CGFloat = 148
        static let reminderRowHeight: CGFloat = 16
        static let checkboxTopInset: CGFloat = 0
        static let rowSpacing: CGFloat = 12
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.rowSpacing) {
            SchemaCheckbox(
                isChecked: task.isCompleted,
                isBlocked: isSequenceBlocked,
                label: task.title,
                hitPadding: 3,
                action: handleToggle
            )
            .padding(.top, Metrics.checkboxTopInset)
            .zIndex(1)

            titleColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .rowClickHandling(onSingleClick: onSelect, onDoubleClick: onOpenDetail)

            trailingMetadata
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            // Clicks on padding/gaps land here; controls in front keep their own clicks.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowBackground)
                .shadow(color: .black.opacity(isLifted ? 0.12 : 0), radius: 8, y: 2)
                .contentShape(Rectangle())
                .rowClickHandling(onSingleClick: onSelect, onDoubleClick: onOpenDetail)
        }
        .animation(SchemaMotion.fast, value: isHovered)
        .animation(SchemaMotion.fast, value: isLifted)
        .animation(SchemaMotion.standard, value: isHighlighted)
        .animation(SchemaMotion.standard, value: isKeyboardSelected)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open Details") {
                onOpenDetail()
            }

            Button("Set Reminder") {
                openReminderPicker()
            }

            if task.reminderTime != nil {
                Button("Remove Reminder") {
                    onSetReminder(nil)
                }
            }

            Divider()

            Button("Delete Task", role: .destructive, action: onDelete)
        }
        .popover(isPresented: $showReminderPicker) {
            reminderPickerContent
        }
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(task.title)
                    .font(.schemaTask)
                    .foregroundStyle(task.isCompleted ? SchemaTheme.inkFaint : .primary)
                    .strikethrough(task.isCompleted, color: SchemaTheme.inkFaint)
                    .opacity(task.isCompleted ? 0.75 : 1)
                    .lineLimit(2)
                    .truncationMode(.tail)

                if task.isRoutine {
                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            task.isCompleted
                                ? SchemaTheme.inkFaint.opacity(0.75)
                                : SchemaTheme.inkMuted
                        )
                        .help("Routine task")
                }
            }
            .animation(SchemaMotion.fast, value: task.isCompleted)

            if let description = task.displayDescription {
                Text(description)
                    .font(.satoshi(12))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var trailingMetadata: some View {
        if showListTag {
            HStack(alignment: .center, spacing: Metrics.rowSpacing) {
                reminderColumn
                    .frame(width: Metrics.reminderColumnWidth, alignment: .trailing)

                if let list = task.list {
                    listTag(for: list)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .zIndex(1)
        } else {
            reminderColumn
                .frame(width: Metrics.reminderColumnWidth, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
                .zIndex(1)
        }
    }

    @ViewBuilder
    private var reminderColumn: some View {
        Group {
            if let reminderTime = task.reminderTime {
                Button(action: openReminderPicker) {
                    Text(ReminderFormatting.displayString(for: reminderTime))
                        .font(.spaceGrotesk(12, weight: .medium).monospacedDigit())
                        .foregroundStyle(SchemaTheme.inkMuted)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(
                        width: Metrics.reminderColumnWidth,
                        height: Metrics.reminderRowHeight
                    )
            }
        }
        .frame(width: Metrics.reminderColumnWidth, alignment: .trailing)
        .transition(.opacity)
    }

    private func listTag(for list: SchemaList) -> some View {
        SchemaChip(text: list.displayTagLabel)
            .transition(.opacity)
    }

    private var rowBackground: Color {
        if isLifted {
            return SchemaTheme.surface
        }
        if isHighlighted || isKeyboardSelected {
            return SchemaTheme.surfaceHover
        }
        if isHovered {
            return SchemaTheme.surfaceHover.opacity(0.6)
        }
        return .clear
    }

    private var reminderPickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder")
                .font(.spaceGrotesk(15, weight: .semibold))

            DatePicker(
                "Reminder Time",
                selection: $reminderDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()

            HStack {
                Button("Cancel") {
                    showReminderPicker = false
                }

                if task.reminderTime != nil {
                    Button("Remove", role: .destructive) {
                        onSetReminder(nil)
                        showReminderPicker = false
                    }
                }

                Spacer()

                Button("Save") {
                    onSetReminder(reminderDate)
                    showReminderPicker = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func handleToggle() {
        guard !isSequenceBlocked || task.isCompleted else { return }
        onDeselect()
        withAnimation(SchemaMotion.spring) {
            onToggle()
        }
    }

    private func openReminderPicker() {
        onDeselect()
        reminderDate = task.reminderTime ?? Date().addingTimeInterval(3600)
        showReminderPicker = true
    }
}

private extension View {
    /// Single click selects immediately; a second click opens details. Using a
    /// simultaneous single tap avoids the delay `onTapGesture(count: 1)` would
    /// add while waiting to rule out a double click.
    func rowClickHandling(
        onSingleClick: @escaping () -> Void,
        onDoubleClick: @escaping () -> Void
    ) -> some View {
        self
            .onTapGesture(count: 2, perform: onDoubleClick)
            .simultaneousGesture(TapGesture().onEnded(onSingleClick))
    }
}

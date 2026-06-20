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
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSetReminder: (Date?) -> Void
    let onSelect: () -> Void
    let onDeselect: () -> Void
    let onOpenDetail: () -> Void

    @State private var showReminderPicker = false
    @State private var reminderDate = Date()
    @State private var checkboxScale: CGFloat = 1.0
    @State private var isHovered = false

    private enum Metrics {
        static let reminderColumnWidth: CGFloat = 148
        static let reminderRowHeight: CGFloat = 16
        static let checkboxTopInset: CGFloat = 1
        static let rowSpacing: CGFloat = 12
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.rowSpacing) {
            Button(action: handleToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(checkboxColor)
                    .scaleEffect(checkboxScale)
            }
            .buttonStyle(.plain)
            .disabled(isSequenceBlocked && !task.isCompleted)
            .help(isSequenceBlocked && !task.isCompleted ? "Complete the previous task in the sequence first" : "")
            .padding(.top, Metrics.checkboxTopInset)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(task.isCompleted ? SchemaTheme.completed : .primary)
                        .strikethrough(task.isCompleted, color: SchemaTheme.completed)
                        .opacity(task.isCompleted ? 0.75 : 1)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    if task.isRoutine {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                task.isCompleted
                                    ? SchemaTheme.completed.opacity(0.75)
                                    : SchemaTheme.accent.opacity(0.85)
                            )
                            .help("Routine task")
                    }
                }
                .animation(SchemaMotion.fast, value: task.isCompleted)

                if let description = task.displayDescription {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(SchemaTheme.mutedText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingMetadata
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .animation(SchemaMotion.fast, value: isHovered)
        .animation(SchemaMotion.standard, value: isHighlighted)
        .animation(SchemaMotion.standard, value: isKeyboardSelected)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpenDetail()
        }
        .onTapGesture {
            onSelect()
        }
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
        } else {
            reminderColumn
                .frame(width: Metrics.reminderColumnWidth, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private var reminderColumn: some View {
        Group {
            if let reminderTime = task.reminderTime {
                Button(action: openReminderPicker) {
                    Text(ReminderFormatting.displayString(for: reminderTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SchemaTheme.accent.opacity(0.85))
                }
                .buttonStyle(.plain)
            } else if isHovered, !task.isCompleted {
                Button(action: openReminderPicker) {
                    Text("Add time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SchemaTheme.mutedText)
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
        Text(list.displayTagLabel)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(SchemaTheme.listTagForeground(for: list))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(SchemaTheme.listTagBackground(for: list))
            )
            .transition(.opacity)
    }

    private var checkboxColor: Color {
        if task.isCompleted {
            return SchemaTheme.accent
        }
        if isSequenceBlocked {
            return SchemaTheme.mutedText.opacity(0.25)
        }
        return SchemaTheme.mutedText.opacity(0.55)
    }

    private var rowBackground: Color {
        if isHighlighted {
            return SchemaTheme.accent.opacity(0.06)
        }
        if isKeyboardSelected {
            return SchemaTheme.accent.opacity(0.08)
        }
        if isHovered {
            return SchemaTheme.rowHoverBackground()
        }
        return .clear
    }

    private var reminderPickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder")
                .font(.headline)

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
            checkboxScale = 0.94
            onToggle()
        }
        withAnimation(SchemaMotion.spring.delay(0.08)) {
            checkboxScale = 1.0
        }
    }

    private func openReminderPicker() {
        onDeselect()
        reminderDate = task.reminderTime ?? Date().addingTimeInterval(3600)
        showReminderPicker = true
    }
}

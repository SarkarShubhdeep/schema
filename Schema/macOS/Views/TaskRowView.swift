//
//  TaskRowView.swift
//  Schema
//

import SwiftUI

struct TaskRowView: View {
    @Bindable var task: SchemaTask
    let isHighlighted: Bool
    let showListTag: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onUpdateTitle: (String) -> Void
    let onSetReminder: (Date?) -> Void

    @State private var showReminderPicker = false
    @State private var reminderDate = Date()
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var checkboxScale: CGFloat = 1.0
    @State private var isHovered = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: handleToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? SchemaTheme.accent : SchemaTheme.mutedText.opacity(0.55))
                    .scaleEffect(checkboxScale)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                titleView

                if let description = task.displayDescription {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(SchemaTheme.mutedText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            reminderColumn

            if showListTag, let list = task.list {
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .animation(SchemaMotion.fast, value: isHovered)
        .animation(SchemaMotion.standard, value: isHighlighted)
        .onHover { isHovered = $0 }
        .contextMenu {
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
    private var reminderColumn: some View {
        if let reminderTime = task.reminderTime {
            Button(action: openReminderPicker) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                    Text(ReminderFormatting.displayString(for: reminderTime))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(SchemaTheme.accent.opacity(0.85))
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else if isHovered, !task.isCompleted {
            Button(action: openReminderPicker) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                    Text("Add time")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }

    private var rowBackground: Color {
        if isHighlighted {
            return SchemaTheme.accent.opacity(0.06)
        }
        if isHovered {
            return Color.black.opacity(0.04)
        }
        return .clear
    }

    @ViewBuilder
    private var titleView: some View {
        if isEditingTitle {
            TextField("Task title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(task.isCompleted ? SchemaTheme.completed : .primary)
                .focused($isTitleFocused)
                .onSubmit(commitTitleEdit)
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused, isEditingTitle {
                        commitTitleEdit()
                    }
                }
                .onKeyPress(.escape) {
                    cancelTitleEdit()
                    return .handled
                }
        } else {
            Text(task.title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(task.isCompleted ? SchemaTheme.completed : .primary)
                .strikethrough(task.isCompleted, color: SchemaTheme.completed)
                .opacity(task.isCompleted ? 0.75 : 1)
                .animation(SchemaMotion.fast, value: task.isCompleted)
                .contentShape(Rectangle())
                .onTapGesture {
                    beginTitleEdit()
                }
        }
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
        withAnimation(SchemaMotion.spring) {
            checkboxScale = 0.94
            onToggle()
        }
        withAnimation(SchemaMotion.spring.delay(0.08)) {
            checkboxScale = 1.0
        }
    }

    private func beginTitleEdit() {
        editedTitle = task.title
        isEditingTitle = true
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    private func commitTitleEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            onUpdateTitle(trimmed)
        }
        isEditingTitle = false
        isTitleFocused = false
    }

    private func cancelTitleEdit() {
        editedTitle = task.title
        isEditingTitle = false
        isTitleFocused = false
    }

    private func openReminderPicker() {
        reminderDate = task.reminderTime ?? Date().addingTimeInterval(3600)
        showReminderPicker = true
    }
}

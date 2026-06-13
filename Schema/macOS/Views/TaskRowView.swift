//
//  TaskRowView.swift
//  Schema
//

import SwiftUI

struct TaskRowView: View {
    @Bindable var task: SchemaTask
    let isHighlighted: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onUpdateTitle: (String) -> Void
    let onSetReminder: (Date?) -> Void

    @State private var showReminderPicker = false
    @State private var reminderDate = Date()
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? SchemaTheme.accent : SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                titleView

                if let description = task.displayDescription {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(SchemaTheme.mutedText)
                }

                reminderView
            }

            Spacer(minLength: 0)

            Menu {
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
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(SchemaTheme.mutedText)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? SchemaTheme.accent.opacity(0.08) : SchemaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHighlighted ? SchemaTheme.accent.opacity(0.35) : .clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .popover(isPresented: $showReminderPicker) {
            reminderPickerContent
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if isEditingTitle {
            TextField("Task title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(task.isCompleted ? SchemaTheme.completed : .primary)
                .strikethrough(task.isCompleted, color: SchemaTheme.completed)
                .contentShape(Rectangle())
                .onTapGesture {
                    beginTitleEdit()
                }
                .help("Click to edit title")
        }
    }

    @ViewBuilder
    private var reminderView: some View {
        if let reminderTime = task.reminderTime {
            Button(action: openReminderPicker) {
                Label(
                    reminderTime.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "bell.fill"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SchemaTheme.accent.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Click to edit reminder")
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

//
//  TaskRowView.swift
//  Schema
//

import SwiftUI

struct TaskRowView: View {
    @Bindable var task: SchemaTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSetReminder: (Date?) -> Void

    @State private var showReminderPicker = false
    @State private var reminderDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? SchemaTheme.accent : SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(task.isCompleted ? SchemaTheme.completed : .primary)
                    .strikethrough(task.isCompleted, color: SchemaTheme.completed)

                if let description = task.displayDescription {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(SchemaTheme.mutedText)
                }

                if let reminderTime = task.reminderTime {
                    Label(reminderTime.formatted(date: .abbreviated, time: .shortened), systemImage: "bell.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SchemaTheme.accent.opacity(0.85))
                }
            }

            Spacer(minLength: 0)

            Menu {
                Button("Set Reminder") {
                    reminderDate = task.reminderTime ?? Date().addingTimeInterval(3600)
                    showReminderPicker = true
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
        .background(SchemaTheme.surface)
        .popover(isPresented: $showReminderPicker) {
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
    }
}

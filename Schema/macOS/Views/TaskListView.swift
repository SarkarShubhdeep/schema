//
//  TaskListView.swift
//  Schema
//

import SwiftUI

struct TaskListView: View {
    let incompleteTasks: [SchemaTask]
    let completedTasks: [SchemaTask]
    let highlightedTaskID: UUID?
    let onToggle: (SchemaTask) -> Void
    let onDelete: (SchemaTask) -> Void
    let onSetReminder: (SchemaTask, Date?) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if incompleteTasks.isEmpty && completedTasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Press n to add your first task.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    ForEach(incompleteTasks) { task in
                        TaskRowView(
                            task: task,
                            isHighlighted: highlightedTaskID == task.id,
                            onToggle: { onToggle(task) },
                            onDelete: { onDelete(task) },
                            onSetReminder: { date in onSetReminder(task, date) }
                        )
                    }

                    if !completedTasks.isEmpty {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SchemaTheme.mutedText)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        ForEach(completedTasks) { task in
                            TaskRowView(
                                task: task,
                                isHighlighted: highlightedTaskID == task.id,
                                onToggle: { onToggle(task) },
                                onDelete: { onDelete(task) },
                                onSetReminder: { date in onSetReminder(task, date) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(SchemaTheme.background)
    }
}

//
//  TaskListView.swift
//  Schema
//

import SwiftUI

struct TaskListView: View {
    let incompleteTasks: [SchemaTask]
    let completedTasks: [SchemaTask]
    let highlightedTaskID: UUID?
    let showListTags: Bool
    let selectedListID: UUID?
    let editingTaskID: UUID?
    let sortOption: TaskSortOption
    let filterOption: TaskFilterOption
    let onToggle: (SchemaTask) -> Void
    let onDelete: (SchemaTask) -> Void
    let onUpdateTitle: (SchemaTask, String) -> Void
    let onSetReminder: (SchemaTask, Date?) -> Void
    let onEditingTaskIDChange: (UUID?) -> Void

    @State private var showCompleted = false

    private var contentAnimationKey: String {
        "\(selectedListID?.uuidString ?? "")-\(sortOption.rawValue)-\(filterOption.rawValue)"
    }

    private var taskRowTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .bottom))
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if incompleteTasks.isEmpty && completedTasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "checklist",
                        description: Text("Press n to add your first task.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .transition(.opacity)
                } else {
                    taskSection
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .opacity(1)
            .offset(y: 0)
            .id(contentAnimationKey)
            .transition(.opacity.combined(with: .offset(y: 4)))
        }
        .background(SchemaTheme.background)
        .animation(SchemaMotion.smooth, value: contentAnimationKey)
    }

    @ViewBuilder
    private var taskSection: some View {
        ForEach(incompleteTasks) { task in
            TaskRowView(
                task: task,
                isHighlighted: highlightedTaskID == task.id,
                showListTag: showListTags,
                isEditing: editingTaskID == task.id,
                onToggle: { onToggle(task) },
                onDelete: { onDelete(task) },
                onUpdateTitle: { title in onUpdateTitle(task, title) },
                onSetReminder: { date in onSetReminder(task, date) },
                onEditingChange: { isEditing in
                    onEditingTaskIDChange(isEditing ? task.id : nil)
                }
            )
            .transition(taskRowTransition)
        }
        .animation(SchemaMotion.smooth, value: incompleteTasks.map(\.id))

        if !completedTasks.isEmpty {
            Button {
                withAnimation(SchemaMotion.smooth) {
                    showCompleted.toggle()
                }
            } label: {
                HStack {
                    Text("Completed (\(completedTasks.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SchemaTheme.mutedText)
                        .textCase(.uppercase)

                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SchemaTheme.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)

            if showCompleted {
                ForEach(completedTasks) { task in
                    TaskRowView(
                        task: task,
                        isHighlighted: highlightedTaskID == task.id,
                        showListTag: showListTags,
                        isEditing: editingTaskID == task.id,
                        onToggle: { onToggle(task) },
                        onDelete: { onDelete(task) },
                        onUpdateTitle: { title in onUpdateTitle(task, title) },
                        onSetReminder: { date in onSetReminder(task, date) },
                        onEditingChange: { isEditing in
                            onEditingTaskIDChange(isEditing ? task.id : nil)
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
    }
}

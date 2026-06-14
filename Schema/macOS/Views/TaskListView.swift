//
//  TaskListView.swift
//  Schema
//

import SwiftUI

struct TaskListView: View {
    let incompleteTasks: [SchemaTask]
    let completedTasks: [SchemaTask]
    let highlightedTaskID: UUID?
    let selectedTaskIDs: Set<UUID>
    let primarySelectedTaskID: UUID?
    let showListTags: Bool
    let selectedListID: UUID?
    let editingTaskID: UUID?
    let sortOption: TaskSortOption
    let filterOption: TaskFilterOption
    let navigableTaskIDs: [UUID]
    let isAddTaskFocused: Bool
    let isEditingListName: Bool
    let onToggle: (SchemaTask) -> Void
    let onDelete: (SchemaTask) -> Void
    let onUpdateTitle: (SchemaTask, String) -> Void
    let onSetReminder: (SchemaTask, Date?) -> Void
    let onEditingTaskIDChange: (UUID?) -> Void
    let onSelectTask: (UUID) -> Void
    let onClearSelection: () -> Void
    let onToggleSelected: (Set<UUID>) -> Void
    let onDeleteSelected: (Set<UUID>) -> Void
    let onDuplicateSelected: (Set<UUID>) -> Void
    let onSelectAllPending: () -> Void
    @Binding var selectedTaskIDsBinding: Set<UUID>
    @Binding var primarySelectedTaskIDBinding: UUID?
    @Binding var selectionAnchorIDBinding: UUID?
    @Binding var editingTaskIDBinding: UUID?
    var isTaskListFocused: FocusState<Bool>.Binding

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
        ScrollViewReader { proxy in
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
                .id(contentAnimationKey)
            }
            .background(SchemaTheme.background)
            .animation(SchemaMotion.fast, value: contentAnimationKey)
            .focusable()
            .focused(isTaskListFocused)
            .focusEffectDisabled()
            .taskListKeyboardNavigation(
                navigableTaskIDs: navigableTaskIDs,
                selectedTaskIDs: $selectedTaskIDsBinding,
                primarySelectedTaskID: $primarySelectedTaskIDBinding,
                selectionAnchorID: $selectionAnchorIDBinding,
                editingTaskID: $editingTaskIDBinding,
                isTaskListFocused: isTaskListFocused,
                isAddTaskFocused: isAddTaskFocused,
                isEditingListName: isEditingListName,
                onToggleSelected: onToggleSelected,
                onDeleteSelected: onDeleteSelected,
                onDuplicateSelected: onDuplicateSelected,
                onSelectAllPending: onSelectAllPending,
                onClearSelection: onClearSelection
            )
            .onChange(of: primarySelectedTaskID) { _, taskID in
                guard let taskID else { return }

                if completedTasks.contains(where: { $0.id == taskID }), !showCompleted {
                    withAnimation(SchemaMotion.fast) {
                        showCompleted = true
                    }
                }

                withAnimation(SchemaMotion.fast) {
                    proxy.scrollTo(taskID, anchor: .center)
                }
            }
            .onTapGesture {
                isTaskListFocused.wrappedValue = true
            }
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        ForEach(incompleteTasks) { task in
            taskRow(for: task)
                .id(task.id)
                .transition(taskRowTransition)
        }
        .animation(SchemaMotion.fast, value: incompleteTasks.map(\.id))

        if !completedTasks.isEmpty {
            Button {
                onClearSelection()
                withAnimation(SchemaMotion.fast) {
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
                    taskRow(for: task)
                        .id(task.id)
                        .transition(.opacity)
                }
            }
        }
    }

    private func taskRow(for task: SchemaTask) -> some View {
        TaskRowView(
            task: task,
            isHighlighted: highlightedTaskID == task.id,
            isKeyboardSelected: selectedTaskIDs.contains(task.id),
            showListTag: showListTags,
            isEditing: editingTaskID == task.id,
            onToggle: { onToggle(task) },
            onDelete: { onDelete(task) },
            onUpdateTitle: { title in onUpdateTitle(task, title) },
            onSetReminder: { date in onSetReminder(task, date) },
            onEditingChange: { isEditing in
                onEditingTaskIDChange(isEditing ? task.id : nil)
            },
            onSelect: {
                onSelectTask(task.id)
                isTaskListFocused.wrappedValue = true
            },
            onDeselect: onClearSelection
        )
    }
}

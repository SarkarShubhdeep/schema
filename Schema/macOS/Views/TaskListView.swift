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
    let sortOption: TaskSortOption
    let filterOption: TaskFilterOption
    let navigableTaskIDs: [UUID]
    let isAddTaskFocused: Bool
    let isEditingListName: Bool
    let isDetailOpen: Bool
    let isSequenceBlocked: (SchemaTask) -> Bool
    let canMoveTask: (SchemaTask) -> Bool
    let isChainHead: (SchemaTask) -> Bool
    let onToggle: (SchemaTask) -> Void
    let onDelete: (SchemaTask) -> Void
    let onSetReminder: (SchemaTask, Date?) -> Void
    let onSelectTask: (UUID) -> Void
    let onClearSelection: () -> Void
    let onToggleSelected: (Set<UUID>) -> Void
    let onDeleteSelected: (Set<UUID>) -> Void
    let onDuplicateSelected: (Set<UUID>) -> Void
    let onSelectAllPending: () -> Void
    let onOpenDetail: (UUID) -> Void
    let onMove: (IndexSet, Int) -> Void
    @Binding var selectedTaskIDsBinding: Set<UUID>
    @Binding var primarySelectedTaskIDBinding: UUID?
    @Binding var selectionAnchorIDBinding: UUID?
    var isTaskListFocused: FocusState<Bool>.Binding

    @State private var showCompleted = false
    @State private var hasLoaded = false

    private var contentAnimationKey: String {
        "\(selectedListID?.uuidString ?? "")-\(sortOption.rawValue)-\(filterOption.rawValue)"
    }

    // Plain opacity only. `.move(edge:)` transitions fight `List`'s own row
    // layout, which leaves rows squished/misaligned until a scroll forces a
    // re-layout.
    private var taskRowTransition: AnyTransition {
        .opacity
    }

    private var contentAnimation: Animation? {
        hasLoaded ? SchemaMotion.fast : nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                List {
                    if incompleteTasks.isEmpty && completedTasks.isEmpty {
                        ContentUnavailableView(
                            "No tasks yet",
                            systemImage: "checklist",
                            description: Text("Press n to add your first task.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                        .transition(.opacity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                    } else {
                        taskSection
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Color.clear
                    .allowsHitTesting(false)
                    .focusable()
                    .focused(isTaskListFocused)
                    .focusEffectDisabled()
            }
            .background(SchemaTheme.background)
            .animation(contentAnimation, value: contentAnimationKey)
            .onAppear {
                // Avoid animating the initial population, which is what produces
                // the first-load layout glitch.
                DispatchQueue.main.async { hasLoaded = true }
            }
            .taskListKeyboardNavigation(
                navigableTaskIDs: navigableTaskIDs,
                selectedTaskIDs: $selectedTaskIDsBinding,
                primarySelectedTaskID: $primarySelectedTaskIDBinding,
                selectionAnchorID: $selectionAnchorIDBinding,
                isTaskListFocused: isTaskListFocused,
                isAddTaskFocused: isAddTaskFocused,
                isEditingListName: isEditingListName,
                isDetailOpen: isDetailOpen,
                onToggleSelected: onToggleSelected,
                onDeleteSelected: onDeleteSelected,
                onDuplicateSelected: onDuplicateSelected,
                onSelectAllPending: onSelectAllPending,
                onClearSelection: onClearSelection,
                onOpenDetail: onOpenDetail
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
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        ForEach(incompleteTasks) { task in
            taskRow(for: task)
                .id(task.id)
                .transition(taskRowTransition)
                .moveDisabled(!canMoveTask(task))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 1, leading: 28, bottom: 1, trailing: 28))
        }
        .onMove(perform: onMove)
        .animation(contentAnimation, value: incompleteTasks.map(\.id))

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
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))

            if showCompleted {
                ForEach(completedTasks) { task in
                    taskRow(for: task)
                        .id(task.id)
                        .transition(.opacity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 1, leading: 28, bottom: 1, trailing: 28))
                }
            }
        }
    }

    private func taskRow(for task: SchemaTask) -> some View {
        TaskRowView(
            task: task,
            isHighlighted: highlightedTaskID == task.id,
            isKeyboardSelected: selectedTaskIDs.contains(task.id),
            isSequenceBlocked: isSequenceBlocked(task),
            showListTag: showListTags,
            onToggle: { onToggle(task) },
            onDelete: { onDelete(task) },
            onSetReminder: { date in onSetReminder(task, date) },
            onSelect: {
                onSelectTask(task.id)
                isTaskListFocused.wrappedValue = true
            },
            onDeselect: onClearSelection,
            onOpenDetail: { onOpenDetail(task.id) }
        )
    }
}

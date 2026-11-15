//
//  WorkspaceView.swift
//  Schema
//

import SwiftUI

/// The main window content: context bar, list tabs, quick entry, task list,
/// and the task detail panel. Action handlers live in
/// `WorkspaceView+Actions.swift`; transient UI state lives in `WorkspaceState`.
struct WorkspaceView: View {
    @Environment(WorkspaceState.self) var workspace

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let taskViewModel: TaskViewModel
    let notificationService: NotificationService

    @FocusState var isAddTaskFocused: Bool
    @FocusState var isTaskListFocused: Bool

    var selectedList: SchemaList? {
        listViewModel.selectedList(from: lists)
    }

    var incompleteTasks: [SchemaTask] {
        taskViewModel.incompleteTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        )
    }

    var completedTasks: [SchemaTask] {
        taskViewModel.completedTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        )
    }

    var body: some View {
        @Bindable var workspace = workspace
        let incomplete = incompleteTasks
        let completed = completedTasks
        let navigableTaskIDs = (incomplete + completed).map(\.id)
        let requiresManualSort = RoutineSequenceOrdering.requiresManualSort(for: selectedList, in: allTasks)

        VStack(spacing: 0) {
            ListContextBar(
                onAllLists: {
                    workspace.clearSelection()
                    workspace.navigationPath.append(WorkspaceRoute.allLists)
                },
                listViewModel: listViewModel,
                requiresManualSort: requiresManualSort
            )

            ListNavigationBar(
                lists: lists,
                selectedListID: listViewModel.selectedListID,
                taskCount: taskCount,
                onSelect: { list in
                    workspace.clearSelection()
                    listViewModel.selectList(list)
                },
                onRename: { list, title in
                    listViewModel.updateListTitle(list, title: title)
                },
                isEditingListName: $workspace.isEditingListName
            )

            AddTaskBar(
                text: Binding(
                    get: { taskViewModel.quickEntryText },
                    set: { taskViewModel.quickEntryText = $0 }
                ),
                isExpanded: $workspace.isAddTaskExpanded,
                placeholder: quickEntryPlaceholder,
                parsedMentions: quickEntryParsedMentions,
                selectedListCandidateIndex: $workspace.quickEntryListCandidateIndex,
                onSubmit: submitQuickEntry,
                onCancel: closeAddTask,
                onOpen: workspace.clearSelection,
                onNavigateUp: { moveSelectionFromAddTask(by: -1, in: navigableTaskIDs) },
                onNavigateDown: { moveSelectionFromAddTask(by: 1, in: navigableTaskIDs) },
                focusBinding: $isAddTaskFocused
            )

            TaskListView(
                listID: listViewModel.selectedListID,
                incompleteTasks: incomplete,
                completedTasks: completed,
                showListTags: selectedList?.isEverythingList == true,
                taskViewModel: taskViewModel,
                isSequenceBlocked: { task in
                    RoutineSequenceOrdering.isBlocked(
                        task,
                        in: allTasks,
                        allowIndependentFollowerCompletion: workspace.allowIndependentFollowerRoutineCompletion
                    )
                },
                actions: TaskListActions(
                    onToggle: toggleCompletion,
                    onDelete: { taskViewModel.deleteTask($0) },
                    onSetReminder: setReminder,
                    onOpenDetail: openTaskDetail,
                    onReorder: reorderTask
                ),
                isTaskListFocused: $isTaskListFocused
            )
            .taskListKeyboardNavigation(
                navigableTaskIDs: navigableTaskIDs,
                isAddTaskFocused: isAddTaskFocused,
                isTaskListFocused: $isTaskListFocused,
                actions: TaskListKeyboardActions(
                    onToggleSelected: toggleSelected,
                    onDeleteSelected: deleteSelected,
                    onDuplicateSelected: duplicateSelected,
                    onSelectAllPending: selectAllPending,
                    onOpenDetail: openTaskDetail
                )
            )
        }
        .overlay(alignment: .topTrailing) {
            detailPanel
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(SchemaTheme.canvas)
        .clickOutsideDismiss(isActive: workspace.hasDismissibleState) {
            dismissActiveEditing()
        }
        .onChange(of: workspace.focusRequest) { _, request in
            guard let request else { return }
            isAddTaskFocused = request.target == .addTask
            isTaskListFocused = request.target == .taskList
        }
        .onChange(of: workspace.isAddTaskExpanded) { _, expanded in
            if expanded {
                workspace.clearSelection()
            } else {
                workspace.requestFocus(.taskList)
            }
        }
        .onChange(of: listViewModel.selectedListID) { _, _ in
            workspace.clearSelection()
            enforceManualSortIfNeeded()
        }
        .onChange(of: requiresManualSort) { _, required in
            if required {
                enforceManualSortIfNeeded()
            }
        }
        .onChange(of: listViewModel.sortOption) { _, _ in
            workspace.clearSelection()
        }
        .onChange(of: listViewModel.filterOption) { _, _ in
            workspace.clearSelection()
        }
        .onChange(of: navigableTaskIDs) { _, ids in
            workspace.pruneSelection(toVisible: ids)
        }
        .alert("Routine Sequence", isPresented: Binding(
            get: { workspace.sequenceValidationAlert != nil },
            set: { if !$0 { workspace.sequenceValidationAlert = nil } }
        )) {
            Button("Remove follower times", action: removeFollowerTimesFromDetailEditor)
            Button("OK", role: .cancel) {}
        } message: {
            if let alert = workspace.sequenceValidationAlert {
                Text("\(alert.message)\n\n\(alert.suggestion)")
            }
        }
        .workspaceKeyboardShortcuts(
            isAddTaskExpanded: $workspace.isAddTaskExpanded,
            isAddTaskFocused: $isAddTaskFocused,
            lists: lists,
            canUndo: taskViewModel.canUndo,
            onSelectListAtIndex: { index in
                withAnimation(SchemaMotion.smooth) {
                    listViewModel.selectList(at: index, from: lists)
                }
            },
            onSelectNextList: {
                withAnimation(SchemaMotion.smooth) {
                    listViewModel.selectNextList(from: lists)
                }
            },
            onSelectPreviousList: {
                withAnimation(SchemaMotion.smooth) {
                    listViewModel.selectPreviousList(from: lists)
                }
            },
            onSelectEverythingList: {
                withAnimation(SchemaMotion.smooth) {
                    listViewModel.selectEverythingList(from: lists)
                }
            },
            onCreateList: {
                listViewModel.showNewListSheet = true
            },
            onCloseAddTask: closeAddTask,
            onUndo: {
                withAnimation(SchemaMotion.smooth) {
                    taskViewModel.undo()
                }
            }
        )
        .sheet(isPresented: Binding(
            get: { listViewModel.showNewListSheet },
            set: { listViewModel.showNewListSheet = $0 }
        )) {
            NewListSheet(
                title: Binding(
                    get: { listViewModel.newListTitle },
                    set: { listViewModel.newListTitle = $0 }
                ),
                onCreate: {
                    listViewModel.createList(title: listViewModel.newListTitle, existingLists: lists)
                },
                onCancel: {
                    listViewModel.newListTitle = ""
                    listViewModel.showNewListSheet = false
                }
            )
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let editor = workspace.taskDetailEditor,
           let task = allTasks.first(where: { $0.id == editor.taskID }) {
            TaskDetailSheet(
                editor: editor,
                listTagLabel: task.list?.displayTagLabel,
                availableLists: lists,
                sequenceCandidates: routineSequenceCandidates(for: task),
                allTasks: allTasks,
                isCompleted: task.isCompleted,
                onCloseRequest: saveAndCloseTaskDetail,
                onToggleCompletion: { toggleCompletion(task) },
                onDelete: {
                    taskViewModel.deleteTask(task)
                    closeTaskDetail()
                },
                onClearFollowerTimes: { taskIDs in
                    Task {
                        await taskViewModel.clearReminderTimes(for: taskIDs, in: allTasks)
                        await refreshNotifications()
                    }
                }
            )
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
    }

    private func taskCount(for list: SchemaList) -> Int {
        if list.isEverythingList {
            return allTasks.filter { !$0.isCompleted }.count
        }
        return list.incompleteTaskCount
    }

    private var quickEntryPlaceholder: String {
        guard let selectedList, !selectedList.isEverythingList else {
            return "Add a task..."
        }
        return "Add a task to \(selectedList.title)..."
    }

    private var quickEntryParsedMentions: ParsedAtMentions? {
        let parsed = AtMentionParser.preview(taskViewModel.quickEntryText, lists: lists)
        return parsed.hasPreviewContent ? parsed : nil
    }
}

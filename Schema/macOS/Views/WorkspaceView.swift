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

    /// Open tasks grouped into Today, Later this week, Later and Someday.
    var incompleteSections: [TaskSectionGroup] {
        TaskSection.group(inSmartView(taskViewModel.incompleteTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        )))
    }

    /// Open tasks in display order (section by section). Keyboard navigation
    /// and drag-to-reorder use this order.
    var incompleteTasks: [SchemaTask] {
        incompleteSections.flatMap(\.tasks)
    }

    var completedTasks: [SchemaTask] {
        inSmartView(taskViewModel.completedTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        ))
    }

    private func inSmartView(_ tasks: [SchemaTask]) -> [SchemaTask] {
        guard let smartView = listViewModel.smartView else { return tasks }
        let now = Date.now
        return tasks.filter { smartView.includes($0, now: now) }
    }

    var body: some View {
        @Bindable var workspace = workspace
        let sections = incompleteSections
        let incomplete = sections.flatMap(\.tasks)
        let completed = completedTasks
        let navigableTaskIDs = (incomplete + completed).map(\.id)
        let requiresManualSort = RoutineSequenceOrdering.requiresManualSort(for: selectedList, in: allTasks)

        VStack(spacing: 0) {
            TaskListView(
                pageKey: listViewModel.smartView?.rawValue ?? listViewModel.selectedListID?.uuidString ?? "",
                header: VStack(alignment: .leading, spacing: 22) {
                    PageHeader(
                        model: headerModel(openCount: incomplete.count, doneCount: completed.count),
                        listViewModel: listViewModel,
                        requiresManualSort: requiresManualSort,
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
                },
                incompleteTasks: incomplete,
                sections: sections,
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
        .frame(minWidth: ShellMetrics.mainMinWidth, minHeight: 520)
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
            pageCount: listViewModel.pages(from: lists).count,
            canUndo: taskViewModel.canUndo,
            onSelectListAtIndex: { index in
                listViewModel.selectList(at: index, from: listViewModel.pages(from: lists))
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

    private var quickEntryPlaceholder: String {
        guard listViewModel.smartView == nil, let selectedList, !selectedList.isEverythingList else {
            return "Add a task… type @ for a page, date or time"
        }
        return "Add to \(selectedList.title)… type @ for a date or time"
    }

    private func headerModel(openCount: Int, doneCount: Int) -> PageHeaderModel {
        if let smartView = listViewModel.smartView {
            return PageHeaderModel(
                crumb: "Views", title: smartView.title,
                kindLabel: "View", kindSystemImage: smartView.systemImage,
                openCount: openCount, doneCount: doneCount, renamableList: nil
            )
        }
        if let selectedList, !selectedList.isEverythingList {
            return PageHeaderModel(
                crumb: "Pages", title: selectedList.title,
                kindLabel: "To-do list", kindSystemImage: "checklist",
                openCount: openCount, doneCount: doneCount, renamableList: selectedList
            )
        }
        return PageHeaderModel(
            crumb: "Views", title: SchemaList.everythingTitle,
            kindLabel: "View", kindSystemImage: "tray.full",
            openCount: openCount, doneCount: doneCount, renamableList: nil
        )
    }

    private var quickEntryParsedMentions: ParsedAtMentions? {
        let parsed = AtMentionParser.preview(taskViewModel.quickEntryText, lists: lists)
        return parsed.hasPreviewContent ? parsed : nil
    }
}

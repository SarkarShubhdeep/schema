//
//  WorkspaceView.swift
//  Schema
//

import AppKit
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
        let open = inSmartView(taskViewModel.incompleteTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        ))
        switch listViewModel.smartView {
        case .today: return TaskSection.groupByPage(open, pages: listViewModel.pages(from: lists))
        case .upcoming: return TaskSection.groupByDay(open)
        case nil: return TaskSection.group(open)
        }
    }

    var dayStats: DayStats {
        DayStats(tasks: allTasks, pages: listViewModel.pages(from: lists))
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

        HStack(spacing: 0) {
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

                    if listViewModel.smartView == .today {
                        TodaySummaryTiles(stats: dayStats)
                    }

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
                // Today groups by page, so the page tag would repeat the heading.
                showListTags: selectedList?.isEverythingList == true && listViewModel.smartView != .today,
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
                    onDeleteSelected: { workspace.requestDelete($0) },
                    onDuplicateSelected: duplicateSelected,
                    onSelectAllPending: selectAllPending,
                    onOpenDetail: openTaskDetail
                )
            )
        }
        .overlay(alignment: .bottom) {
            selectionToolbar
        }
        .animation(SchemaMotion.standard, value: workspace.selectedTaskIDs.isEmpty)
        .frame(minWidth: ShellMetrics.mainMinWidth, maxWidth: .infinity, minHeight: 520)
        .clipped()

            DetailsPanelView(
                detail: taskDetail,
                onCloseDetail: saveAndCloseTaskDetail,
                overview: OverviewPanel(stats: dayStats)
            )
        }
        .animation(SchemaMotion.animation(SchemaMotion.standard, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion), value: workspace.isDetailOpen)
        .background(SchemaTheme.canvas)
        .clickOutsideDismiss(isActive: workspace.hasDismissibleState) {
            dismissActiveEditing()
        }
        .onChange(of: workspace.confirmedDelete) { _, request in
            guard let request else { return }
            if let editor = workspace.taskDetailEditor, request.taskIDs.contains(editor.taskID) {
                closeTaskDetail()
            }
            withAnimation(SchemaMotion.smooth) {
                deleteSelected(request.taskIDs)
            }
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
    private var selectionToolbar: some View {
        let selected = (incompleteTasks + completedTasks).filter { workspace.isSelected($0.id) }
        if !selected.isEmpty, !workspace.isDetailOpen {
            SelectionToolbar(
                count: selected.count,
                isAllCompleted: selected.allSatisfy(\.isCompleted),
                pages: listViewModel.pages(from: lists),
                onReschedule: { rescheduleSelected(to: $0) },
                onMove: { moveSelected(to: $0) },
                onDelete: { workspace.requestDelete(workspace.selectedTaskIDs) },
                onComplete: { toggleSelected(workspace.selectedTaskIDs) },
                onClear: {
                    workspace.clearSelection()
                    workspace.requestFocus(.taskList)
                }
            )
            .keepsSelectionOnClick()
            .padding(.bottom, 24)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// The open task's editor, shown in the details panel.
    private var taskDetail: TaskDetailSheet? {
        guard let editor = workspace.taskDetailEditor,
              let task = allTasks.first(where: { $0.id == editor.taskID }) else { return nil }
        return TaskDetailSheet(
                editor: editor,
                listTagLabel: task.list?.displayTagLabel,
                availableLists: lists,
                sequenceCandidates: routineSequenceCandidates(for: task),
                allTasks: allTasks,
                isCompleted: task.isCompleted,
                onCloseRequest: saveAndCloseTaskDetail,
                onToggleCompletion: { toggleCompletion(task) },
                onDelete: { workspace.requestDelete([task.id]) },
                onClearFollowerTimes: { taskIDs in
                    Task {
                        await taskViewModel.clearReminderTimes(for: taskIDs, in: allTasks)
                        await refreshNotifications()
                    }
                }
            )
    }

    private var quickEntryPlaceholder: String {
        guard listViewModel.smartView == nil, let selectedList, !selectedList.isEverythingList else {
            return "Add a task… type @ for a page, date or time"
        }
        return "Add to \(selectedList.title)… type @ for a date or time"
    }

    private func headerModel(openCount: Int, doneCount: Int) -> PageHeaderModel {
        if listViewModel.smartView == .today {
            return PageHeaderModel(
                crumb: "Views", title: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                kindLabel: "Today", kindSystemImage: SmartView.today.systemImage,
                openCount: openCount, doneCount: doneCount, renamableList: nil,
                showsProgress: false
            )
        }
        if let smartView = listViewModel.smartView {
            return PageHeaderModel(
                crumb: "Views", title: smartView.title,
                kindLabel: "View", kindSystemImage: smartView.systemImage,
                openCount: openCount, doneCount: doneCount, renamableList: nil,
                // Upcoming only holds open tasks, so done-of-total says nothing.
                showsProgress: false
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

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

    /// Lets lines in a scratchpad become tasks (#40).
    var blockTaskActions: BlockTaskActions {
        let taskPages = listViewModel.taskPages(from: lists)
        return BlockTaskActions(
            taskPages: taskPages,
            defaultPage: taskPages.first { $0.id == listViewModel.defaultWritableListID },
            task: { id in allTasks.first { $0.id == id } },
            makeTask: { title, page in
                // addTask clears the quick-add draft; keep it.
                let draft = taskViewModel.quickEntryText
                defer { taskViewModel.quickEntryText = draft }
                return taskViewModel.addTask(to: page, title: title, lists: lists, allTasks: allTasks)
            },
            toggleTask: { task in toggleCompletion(task) },
            openTask: { task in
                withAnimation(SchemaMotion.smooth) {
                    listViewModel.selectList(task.list)
                }
                workspace.highlightedTaskID = task.id
            }
        )
    }

    /// The selected page when it is a scratchpad (and no smart view is shown).
    var scratchpadPage: SchemaList? {
        guard listViewModel.smartView == nil, let selectedList, selectedList.isScratchpad else { return nil }
        return selectedList
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
        case .upcoming: return TaskSection.groupByDay(open, calendar: calendar)
        case nil: return TaskSection.group(open, calendar: calendar)
        }
    }

    /// Reads the week-start setting through `workspace`, so changing it in
    /// Settings redraws the sections and the week chart.
    var calendar: Calendar {
        Calendar.schema(weekStart: workspace.weekStart)
    }

    var dayStats: DayStats {
        DayStats(tasks: allTasks, pages: listViewModel.pages(from: lists), calendar: calendar)
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
            if let task = openTask {
                TaskPageView(
                    task: task,
                    originTitle: originTitle,
                    isBlocked: RoutineSequenceOrdering.isBlocked(
                        task,
                        in: allTasks,
                        allowIndependentFollowerCompletion: workspace.allowIndependentFollowerRoutineCompletion
                    ),
                    actions: taskPageActions(for: task, in: navigableTaskIDs)
                )
                .id(task.id)
            } else if let scratchpad = scratchpadPage {
                ScratchpadPageView(page: scratchpad, taskActions: blockTaskActions)
            } else {
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
        }
        .overlay(alignment: .bottom) {
            selectionToolbar
        }
        .animation(SchemaMotion.appear, value: workspace.selectedTaskIDs.isEmpty)
        // Room for the floating sidebar bar when the sidebar is collapsed.
        .padding(.leading, workspace.isSidebarCollapsed ? ShellMetrics.floatingBarContentInset : 0)
        .frame(minWidth: ShellMetrics.mainMinWidth, maxWidth: .infinity, minHeight: 520)
        .clipped()

            DetailsPanelView(
                title: openTask == nil ? "Overview" : "Task",
                railItems: openTask == nil ? Self.overviewRail : Self.taskRail
            ) {
                if let task = openTask, let editor = workspace.taskDetailEditor {
                    TaskPagePanel(
                        task: task,
                        editor: editor,
                        taskPages: listViewModel.taskPages(from: lists),
                        sequenceCandidates: routineSequenceCandidates(for: task),
                        allTasks: allTasks,
                        calendar: calendar,
                        onSaveSchedule: saveTaskSchedule,
                        onMove: { page in taskViewModel.moveTask(task, to: page, allTasks: allTasks) }
                    )
                } else {
                    OverviewPanel(stats: dayStats)
                }
            }
        }
        .animation(SchemaMotion.smooth, value: workspace.isTaskPageOpen)
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
        .onChange(of: workspace.confirmedPageDelete) { _, request in
            guard let request else { return }
            deletePage(request.pageID)
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
            // Choosing another page in the sidebar leaves an open task page.
            workspace.taskDetailEditor = nil
            workspace.clearSelection()
            enforceManualSortIfNeeded()
        }
        .onChange(of: requiresManualSort) { _, required in
            if required {
                enforceManualSortIfNeeded()
            }
        }
        .onChange(of: listViewModel.smartView) { _, _ in
            workspace.taskDetailEditor = nil
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
            allowsSingleKeyShortcuts: scratchpadPage == nil && !workspace.isTaskPageOpen,
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
            onCreateList: listViewModel.openNewPage,
            onCloseAddTask: closeAddTask,
            onUndo: {
                withAnimation(SchemaMotion.smooth) {
                    taskViewModel.undo()
                }
            }
        )
    }

    @ViewBuilder
    private var selectionToolbar: some View {
        let selected = (incompleteTasks + completedTasks).filter { workspace.isSelected($0.id) }
        if !selected.isEmpty, !workspace.isTaskPageOpen {
            SelectionToolbar(
                count: selected.count,
                isAllCompleted: selected.allSatisfy(\.isCompleted),
                pages: listViewModel.taskPages(from: lists),
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
            .transition(SchemaMotion.moving(.move(edge: .bottom).combined(with: .opacity)))
        }
    }

    static let overviewRail = [
        PanelRailItem(systemImage: "bell", label: "Upcoming reminders"),
        PanelRailItem(systemImage: "chart.bar", label: "This week"),
        PanelRailItem(systemImage: "repeat", label: "Routines"),
    ]

    static let taskRail = [
        PanelRailItem(systemImage: "slider.horizontal.3", label: "Properties"),
        PanelRailItem(systemImage: "checklist", label: "Checklist"),
        PanelRailItem(systemImage: "link", label: "Linked"),
    ]

    /// The task whose page is open (#31).
    var openTask: SchemaTask? {
        guard let editor = workspace.taskDetailEditor else { return nil }
        return allTasks.first { $0.id == editor.taskID }
    }

    /// Where the open task page goes back to: the page or view under it.
    private var originTitle: String {
        if let smartView = listViewModel.smartView { return smartView.title }
        return selectedList?.title ?? "Back"
    }

    private func taskPageActions(for task: SchemaTask, in ids: [UUID]) -> TaskPageActions {
        let index = ids.firstIndex(of: task.id)
        let previous = index.flatMap { $0 > 0 ? ids[$0 - 1] : nil }
        let next = index.flatMap { $0 + 1 < ids.count ? ids[$0 + 1] : nil }
        return TaskPageActions(
            onBack: closeTaskDetail,
            onPrevious: previous.map { id in { openTaskDetail(id) } },
            onNext: next.map { id in { openTaskDetail(id) } },
            onToggle: { toggleCompletion(task) },
            onRename: { taskViewModel.updateTitle(task, title: $0) },
            onDuplicate: {
                if let copy = taskViewModel.duplicateTasks([task], allTasks: allTasks).first {
                    openTaskDetail(copy.id)
                }
            },
            onDelete: { workspace.requestDelete([task.id]) },
            movePages: listViewModel.taskPages(from: lists),
            onMove: { page in taskViewModel.moveTask(task, to: page, allTasks: allTasks) }
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

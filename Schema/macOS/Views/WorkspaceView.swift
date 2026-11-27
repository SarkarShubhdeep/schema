//
//  WorkspaceView.swift
//  Schema
//

import AppKit
import SwiftData
import SwiftUI

/// The main window content: context bar, list tabs, quick entry, task list,
/// and the task detail panel. Action handlers live in
/// `WorkspaceView+Actions.swift`; transient UI state lives in `WorkspaceState`.
struct WorkspaceView: View {
    @Environment(WorkspaceState.self) var workspace
    @Environment(\.modelContext) var modelContext

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let taskViewModel: TaskViewModel
    let notificationService: NotificationService

    @State private var shownTasksMemo = ObservedMemo<(sections: [TaskSectionGroup], completed: [SchemaTask])>()
    @State private var dayStatsMemo = ObservedMemo<DayStats>()
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
            },
            moveTask: { task, page in
                taskViewModel.moveTask(task, to: page, allTasks: allTasks)
            }
        )
    }

    /// The selected page when it is a scratchpad (and no smart view is shown).
    var scratchpadPage: SchemaList? {
        guard listViewModel.selectedListID != nil, let selectedList, selectedList.hasPageBody else { return nil }
        return selectedList
    }

    /// Open tasks grouped into Today, Later this week, Later and Someday.
    var incompleteSections: [TaskSectionGroup] {
        shownTasks.sections
    }

    /// What the list shows, worked out in one pass: open tasks in sections
    /// and done tasks (#45).
    var shownTasks: (sections: [TaskSectionGroup], completed: [SchemaTask]) {
        // Kept between redraws that change nothing it reads, such as moving
        // the selection (#45).
        shownTasksMemo.value(key: memoKey) { computeShownTasks() }
    }

    private func computeShownTasks() -> (sections: [TaskSectionGroup], completed: [SchemaTask]) {
        let (open, done) = taskViewModel.partitionedTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        )
        return (sections(for: inSmartView(open)), inSmartView(done))
    }

    private func sections(for open: [SchemaTask]) -> [TaskSectionGroup] {
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
        dayStatsMemo.value(key: memoKey) {
            DayStats(tasks: allTasks, pages: listViewModel.pages(from: lists), calendar: calendar)
        }
    }

    /// What the memos can't observe: which tasks and pages exist (the
    /// arrays are passed in), and the time, to the minute.
    private var memoKey: MemoKey {
        var hasher = Hasher()
        for task in allTasks { hasher.combine(ObjectIdentifier(task)) }
        for list in lists { hasher.combine(ObjectIdentifier(list)) }
        return MemoKey(models: hasher.finalize(), minute: Int(Date.now.timeIntervalSinceReferenceDate / 60))
    }

    /// Open tasks in display order (section by section). Keyboard navigation
    /// and drag-to-reorder use this order.
    var incompleteTasks: [SchemaTask] {
        incompleteSections.flatMap(\.tasks)
    }

    var completedTasks: [SchemaTask] {
        shownTasks.completed
    }

    private func inSmartView(_ tasks: [SchemaTask]) -> [SchemaTask] {
        guard let smartView = listViewModel.smartView else { return tasks }
        let calendar = Calendar.schema()
        let clock = TaskSectionClock(now: .now, calendar: calendar)
        return tasks.filter { smartView.includes($0, clock: clock, calendar: calendar) }
    }

    var body: some View {
        @Bindable var workspace = workspace
        // A scratchpad shows no tasks, so skip working out the list (#45).
        let shown: (sections: [TaskSectionGroup], completed: [SchemaTask]) = scratchpadPage == nil && !listViewModel.showsPomodoro ? shownTasks : ([], [])
        let sections = shown.sections
        let incomplete = sections.flatMap(\.tasks)
        let completed = shown.completed
        let navigableTaskIDs = (incomplete + completed).map(\.id)
        // Today shows the stats twice (tiles and overview); work them out once.
        let todayStats = listViewModel.smartView == .today ? dayStats : nil
        let requiresManualSort = scratchpadPage == nil && openTask == nil
            && RoutineSequenceOrdering.requiresManualSort(for: selectedList, in: allTasks)

        HStack(spacing: ShellMetrics.margin) {
        VStack(spacing: ShellMetrics.margin) {
            if let task = openTask {
                TaskPageView(
                    task: task,
                    pageTitle: task.list?.title ?? "Task",
                    isBlocked: RoutineSequenceOrdering.isBlocked(
                        task,
                        in: allTasks,
                        allowIndependentFollowerCompletion: workspace.allowIndependentFollowerRoutineCompletion
                    ),
                    actions: taskPageActions(for: task, in: navigableTaskIDs)
                )
                .id(task.id)
            } else if listViewModel.showsPomodoro {
                PomodoroPageView(pages: listViewModel.pages(from: lists)) { page in
                    listViewModel.selectList(page)
                }
            } else if let scratchpad = scratchpadPage {
                ScratchpadPageView(page: scratchpad, taskActions: blockTaskActions)
            } else {
            PageHeaderBar(
                model: headerModel(openCount: incomplete.count, doneCount: completed.count),
                listViewModel: listViewModel,
                requiresManualSort: requiresManualSort
            )
            TaskListView(
                pageKey: pageKey,
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
                        TodaySummaryTiles(stats: todayStats ?? dayStats)
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
                showListTags: listViewModel.selectedListID == nil && listViewModel.smartView != .today,
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
            selectionToolbar(visible: incomplete + completed)
        }
        .animation(SchemaMotion.appear, value: workspace.selectedTaskIDs.isEmpty)
        .frame(minWidth: ShellMetrics.mainMinWidth, maxWidth: .infinity, minHeight: 520)
        // Collapsed, the details panel is its expand button at the top right,
        // beside the page's header (#116).
        .transformEnvironment(\.shellHeaderInsets) { insets in
            insets.trailing = workspace.isDetailsPanelCollapsed ? ShellMetrics.collapsedDetailsWidth + ShellMetrics.margin : 0
        }
        .overlay(alignment: .topTrailing) {
            if workspace.isDetailsPanelCollapsed {
                DetailsPanelPill(title: openTask == nil ? "Overview" : "Task")
                    .transition(SchemaMotion.followingPanel(.opacity.combined(with: .offset(x: 8))))
            }
        }

            if !workspace.isDetailsPanelCollapsed {
            DetailsPanelView(title: openTask == nil ? "Overview" : "Task") {
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
                    OverviewPanel(stats: todayStats ?? dayStats)
                }
            }
            .transition(SchemaMotion.moving(.move(edge: .trailing).combined(with: .opacity)))
            }
        }
        .animation(SchemaMotion.smooth, value: workspace.isTaskPageOpen)
        .environment(\.editorMentionActions, EditorMentionActions(open: openMention, openLine: openTaggedLine))
        .clickOutsideDismiss(isActive: workspace.hasDismissibleState) {
            dismissActiveEditing()
        }
        .onChange(of: workspace.confirmedDelete) { _, request in
            guard let request else { return }
            if let editor = workspace.taskDetailEditor, request.taskIDs.contains(editor.taskID) {
                closeTaskDetail()
            }
            for id in request.taskIDs { listViewModel.navigation.forget(task: id, fallback: listViewModel.context) }
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
        .onChange(of: listViewModel.destination) { old, destination in
            // A task page is a destination (#124): its editor follows it,
            // through back and forward too.
            if let taskID = destination.taskID {
                if workspace.taskDetailEditor?.taskID != taskID,
                   let task = allTasks.first(where: { $0.id == taskID }) {
                    workspace.taskDetailEditor = TaskDetailEditor(task: task)
                    workspace.selectSingle(taskID)
                }
                return
            }
            workspace.taskDetailEditor = nil
            // Back from a task to its list keeps the task selected.
            if old.taskID == nil {
                workspace.clearSelection()
            } else {
                workspace.requestFocus(.taskList)
            }
            enforceManualSortIfNeeded()
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
            canUndo: taskViewModel.canUndo,
            allowsSingleKeyShortcuts: scratchpadPage == nil && !workspace.isTaskPageOpen && !listViewModel.showsPomodoro,
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
    private func selectionToolbar(visible: [SchemaTask]) -> some View {
        let selected = workspace.selectedTaskIDs.isEmpty ? [] : visible.filter { workspace.isSelected($0.id) }
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
            .padding(.bottom, 8)
            .transition(SchemaMotion.moving(.move(edge: .bottom).combined(with: .opacity)))
        }
    }

    /// Keeps each page's and view's scroll position apart.
    private var pageKey: String {
        switch listViewModel.context {
        case .page(let id): id.uuidString
        case .view(let kind): kind.rawValue
        case .tool(let kind): kind.rawValue
        case .task(let id): id.uuidString
        }
    }

    /// The task whose page is open (#31).
    var openTask: SchemaTask? {
        guard let editor = workspace.taskDetailEditor else { return nil }
        return allTasks.first { $0.id == editor.taskID }
    }

    private func taskPageActions(for task: SchemaTask, in ids: [UUID]) -> TaskPageActions {
        let index = ids.firstIndex(of: task.id)
        let previous = index.flatMap { $0 > 0 ? ids[$0 - 1] : nil }
        let next = index.flatMap { $0 + 1 < ids.count ? ids[$0 + 1] : nil }
        return TaskPageActions(
            onBack: closeTaskDetail,
            onOpenPage: task.list.map { page in { withAnimation(SchemaMotion.smooth) { listViewModel.selectList(page) } } },
            onPrevious: previous.map { id in { stepTaskDetail(to: id) } },
            onNext: next.map { id in { stepTaskDetail(to: id) } },
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
        guard listViewModel.selectedListID != nil, let selectedList, !selectedList.isEverythingList else {
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
        if listViewModel.selectedListID != nil, let selectedList, !selectedList.isEverythingList {
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

/// Inputs to WorkspaceView's memos that Observation can't track.
private struct MemoKey: Hashable {
    let models: Int
    let minute: Int
}

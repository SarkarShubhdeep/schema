//
//  ContentView.swift
//  Schema
//

import SwiftUI
import SwiftData

private enum WorkspaceRoute: Hashable {
    case allLists
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SchemaList.order) private var lists: [SchemaList]
    @Query(sort: \SchemaTask.createdAt) private var allTasks: [SchemaTask]

    @State private var listViewModel: ListViewModel?
    @State private var taskViewModel: TaskViewModel?
    @State private var highlightedTaskID: UUID?
    @State private var navigationPath = NavigationPath()
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var allowIndependentFollowerRoutineCompletion = SchemaPreferences.allowIndependentFollowerRoutineCompletion
    @State private var notificationItems: [SchemaNotificationItem] = []
    @State private var isAddTaskExpanded = false
    @State private var quickEntryListCandidateIndex = 0
    @State private var skipAddTaskDismiss = false
    @State private var taskDetailEditor: TaskDetailEditor?
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var primarySelectedTaskID: UUID?
    @State private var selectionAnchorID: UUID?
    @State private var isEditingListName = false
    @State private var sequenceValidationAlert: RoutineSequenceValidationResult?
    @FocusState private var isAddTaskFocused: Bool
    @FocusState private var isTaskListFocused: Bool

    private let notificationService = NotificationService()

    private var selectedList: SchemaList? {
        listViewModel?.selectedList(from: lists)
    }

    private func taskCount(for list: SchemaList) -> Int {
        if list.isEverythingList {
            return allTasks.filter { !$0.isCompleted }.count
        }
        return list.incompleteTaskCount
    }

    var body: some View {
        Group {
            if let listViewModel, let taskViewModel {
                NavigationStack(path: $navigationPath) {
                    workspaceView(
                        listViewModel: listViewModel,
                        taskViewModel: taskViewModel
                    )
                    .navigationDestination(for: WorkspaceRoute.self) { route in
                        switch route {
                        case .allLists:
                            AllListsView(
                                lists: lists,
                                listViewModel: listViewModel,
                                onSelectList: { list in
                                    listViewModel.selectList(list)
                                    navigationPath = NavigationPath()
                                }
                            )
                        }
                    }
                }
                .schemaWindowToolbar()
                .toolbar {
                    AppHeaderToolbar(
                        showNotifications: $showNotifications,
                        showSettings: $showSettings,
                        pendingNotificationCount: notificationItems.count,
                        notificationItems: notificationItems,
                        onNotificationSelect: { item in
                            handleNotificationSelect(item, listViewModel: listViewModel)
                        }
                    )
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(
                        listViewModel: listViewModel,
                        lists: lists,
                        notificationService: notificationService,
                        allowIndependentFollowerRoutineCompletion: $allowIndependentFollowerRoutineCompletion
                    )
                }
                .onChange(of: allowIndependentFollowerRoutineCompletion) { _, newValue in
                    SchemaPreferences.allowIndependentFollowerRoutineCompletion = newValue
                }
                .task {
                    await refreshNotifications()
                }
                .onChange(of: showNotifications) { _, isShowing in
                    if isShowing {
                        Task { await refreshNotifications() }
                    }
                }
                .onChange(of: allTasks.count) { _, _ in
                    Task { await refreshNotifications() }
                }
            } else {
                ProgressView("Loading Schema...")
                    .frame(minWidth: 720, minHeight: 520)
            }
        }
        .onAppear {
            bootstrapIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationNames.taskReminderOpened)) { notification in
            if let listID = notification.openedListID {
                listViewModel?.selectedListID = listID
            }
            highlightedTaskID = notification.openedTaskID
        }
        .onChange(of: lists.count) { _, _ in
            if listViewModel?.selectedListID == nil {
                listViewModel?.selectedListID = lists.first?.id
            }
            if listViewModel?.defaultWritableListID == nil {
                listViewModel?.defaultWritableListID = lists.first(where: { !$0.isEverythingList })?.id
            }
        }
    }

    @ViewBuilder
    private func workspaceView(
        listViewModel: ListViewModel,
        taskViewModel: TaskViewModel
    ) -> some View {
        let incomplete = taskViewModel.incompleteTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        )
        let completed = taskViewModel.completedTasks(
            for: selectedList,
            from: allTasks,
            sortOption: listViewModel.sortOption,
            filterOption: listViewModel.filterOption
        )
        let navigableTaskIDs = (incomplete + completed).map(\.id)
        let requiresManualSort = RoutineSequenceOrdering.requiresManualSort(
            for: selectedList,
            in: allTasks
        )

        VStack(spacing: 0) {
            ListContextBar(
                onAllLists: {
                    clearTaskSelection()
                    navigationPath.append(WorkspaceRoute.allLists)
                },
                listViewModel: listViewModel,
                requiresManualSort: requiresManualSort
            )

            ListNavigationBar(
                lists: lists,
                selectedListID: listViewModel.selectedListID,
                taskCount: taskCount,
                onSelect: { list in
                    clearTaskSelection()
                    listViewModel.selectList(list)
                },
                onRename: { list, title in
                    listViewModel.updateListTitle(list, title: title)
                },
                isEditingListName: $isEditingListName
            )

            AddTaskBar(
                text: Binding(
                    get: { taskViewModel.quickEntryText },
                    set: { taskViewModel.quickEntryText = $0 }
                ),
                isExpanded: $isAddTaskExpanded,
                placeholder: quickEntryPlaceholder,
                parsedMentions: quickEntryParsedMentions(for: taskViewModel),
                selectedListCandidateIndex: $quickEntryListCandidateIndex,
                onSubmit: {
                    submitQuickEntry(taskViewModel: taskViewModel, listViewModel: listViewModel)
                },
                onCancel: closeAddTask,
                onOpen: clearTaskSelection,
                onNavigateUp: { moveSingleTaskSelection(by: -1, in: navigableTaskIDs) },
                onNavigateDown: { moveSingleTaskSelection(by: 1, in: navigableTaskIDs) },
                focusBinding: $isAddTaskFocused
            )

            TaskListView(
                incompleteTasks: incomplete,
                completedTasks: completed,
                highlightedTaskID: highlightedTaskID,
                selectedTaskIDs: selectedTaskIDs,
                primarySelectedTaskID: primarySelectedTaskID,
                showListTags: selectedList?.isEverythingList == true,
                selectedListID: listViewModel.selectedListID,
                sortOption: listViewModel.sortOption,
                filterOption: listViewModel.filterOption,
                navigableTaskIDs: navigableTaskIDs,
                isAddTaskFocused: isAddTaskFocused,
                isEditingListName: isEditingListName,
                isDetailOpen: taskDetailEditor != nil,
                isSequenceBlocked: { task in
                    RoutineSequenceOrdering.isBlocked(
                        task,
                        in: allTasks,
                        allowIndependentFollowerCompletion: allowIndependentFollowerRoutineCompletion
                    )
                },
                canMoveTask: { task in
                    taskViewModel.canMoveTask(task, in: incomplete)
                },
                isChainHead: { task in
                    taskViewModel.isChainHead(task, in: incomplete)
                },
                onToggle: { task in
                    withAnimation(SchemaMotion.smooth) {
                        taskViewModel.toggleCompletion(task, in: allTasks)
                    }
                },
                onDelete: { task in
                    taskViewModel.deleteTask(task)
                },
                onSetReminder: { task, date in
                    Task {
                        await taskViewModel.setReminder(task, at: date)
                        await refreshNotifications()
                    }
                },
                onSelectTask: { taskID in
                    selectSingleTask(taskID)
                },
                onClearSelection: clearTaskSelection,
                onToggleSelected: { taskIDs in
                    handleKeyboardToggleSelected(
                        taskIDs: taskIDs,
                        incomplete: incomplete,
                        completed: completed,
                        taskViewModel: taskViewModel
                    )
                },
                onDeleteSelected: { taskIDs in
                    handleKeyboardDeleteSelected(
                        taskIDs: taskIDs,
                        navigableTaskIDs: navigableTaskIDs,
                        incomplete: incomplete,
                        completed: completed,
                        taskViewModel: taskViewModel
                    )
                },
                onDuplicateSelected: { taskIDs in
                    handleKeyboardDuplicateSelected(
                        taskIDs: taskIDs,
                        incomplete: incomplete,
                        completed: completed,
                        taskViewModel: taskViewModel
                    )
                },
                onSelectAllPending: {
                    selectAllPendingTasks(in: incomplete)
                },
                onOpenDetail: { taskID in
                    openTaskDetail(taskID)
                },
                onMove: { source, destination in
                    handleTaskMove(
                        source: source,
                        destination: destination,
                        incomplete: incomplete,
                        taskViewModel: taskViewModel,
                        listViewModel: listViewModel
                    )
                },
                selectedTaskIDsBinding: $selectedTaskIDs,
                primarySelectedTaskIDBinding: $primarySelectedTaskID,
                selectionAnchorIDBinding: $selectionAnchorID,
                isTaskListFocused: $isTaskListFocused
            )
        }
        .overlay(alignment: .topTrailing) {
            if let taskDetailEditor,
               let task = allTasks.first(where: { $0.id == taskDetailEditor.taskID }) {
                TaskDetailSheet(
                    editor: taskDetailEditor,
                    listTagLabel: task.list?.displayTagLabel,
                    availableLists: lists,
                    sequenceCandidates: routineSequenceCandidates(for: task, in: allTasks),
                    allTasks: allTasks,
                    isCompleted: task.isCompleted,
                    onCloseRequest: {
                        saveAndCloseTaskDetail(taskViewModel: taskViewModel)
                    },
                    onToggleCompletion: {
                        withAnimation(SchemaMotion.smooth) {
                            taskViewModel.toggleCompletion(task, in: allTasks)
                        }
                    },
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
        .frame(minWidth: 720, minHeight: 520)
        .background(SchemaTheme.background)
        .clickOutsideDismiss(isActive: isAddTaskExpanded || taskDetailEditor != nil || !selectedTaskIDs.isEmpty) {
            dismissActiveEditing(taskViewModel: taskViewModel)
        }
        .onChange(of: isAddTaskExpanded) { _, expanded in
            if expanded {
                clearTaskSelection()
            } else {
                DispatchQueue.main.async {
                    isTaskListFocused = true
                }
            }
        }
        .onChange(of: listViewModel.selectedListID) { _, _ in
            clearTaskSelection()
            enforceManualSortIfNeeded(listViewModel: listViewModel)
        }
        .onChange(of: requiresManualSort) { _, required in
            if required {
                enforceManualSortIfNeeded(listViewModel: listViewModel)
            }
        }
        .onChange(of: listViewModel.sortOption) { _, _ in
            clearTaskSelection()
        }
        .onChange(of: listViewModel.filterOption) { _, _ in
            clearTaskSelection()
        }
        .onChange(of: navigableTaskIDs) { _, ids in
            let validIDs = Set(ids)
            selectedTaskIDs = selectedTaskIDs.intersection(validIDs)
            if let primarySelectedTaskID, !validIDs.contains(primarySelectedTaskID) {
                self.primarySelectedTaskID = selectedTaskIDs.first
                selectionAnchorID = selectedTaskIDs.first
            }
        }
        .alert("Routine Sequence", isPresented: Binding(
            get: { sequenceValidationAlert != nil },
            set: { isPresented in
                if !isPresented {
                    sequenceValidationAlert = nil
                }
            }
        )) {
            Button("Remove follower times") {
                removeFollowerTimesFromDetailEditor(taskViewModel: taskViewModel)
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let sequenceValidationAlert {
                Text("\(sequenceValidationAlert.message)\n\n\(sequenceValidationAlert.suggestion)")
            }
        }
        .workspaceKeyboardShortcuts(
            isAddTaskExpanded: $isAddTaskExpanded,
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

    private var quickEntryPlaceholder: String {
        if let selectedList {
            if selectedList.isEverythingList {
                return "Add a task..."
            }
            return "Add a task to \(selectedList.title)..."
        }
        return "Add a task..."
    }

    private func quickEntryParsedMentions(for taskViewModel: TaskViewModel) -> ParsedAtMentions? {
        let parsed = AtMentionParser.preview(taskViewModel.quickEntryText, lists: lists)
        return parsed.hasPreviewContent ? parsed : nil
    }

    private func bootstrapIfNeeded() {
        guard listViewModel == nil else { return }

        let listVM = ListViewModel(modelContext: modelContext)
        listVM.ensureDefaultListsIfNeeded(from: lists)
        if listVM.selectedListID == nil {
            listVM.selectedListID = lists.first?.id
        }
        if listVM.defaultWritableListID == nil {
            listVM.defaultWritableListID = lists.first(where: { !$0.isEverythingList })?.id
        }
        listViewModel = listVM
        taskViewModel = TaskViewModel(
            modelContext: modelContext,
            notificationService: notificationService
        )

        let routineResetService = RoutineResetService(modelContext: modelContext)
        routineResetService.resetRoutineTasksIfNeeded(tasks: allTasks)

        Task {
            await notificationService.rescheduleAllReminders(for: allTasks)
            await refreshNotifications()
        }
    }

    private func submitQuickEntry(taskViewModel: TaskViewModel, listViewModel: ListViewModel) {
        guard !taskViewModel.quickEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let parsed = AtMentionParser.commit(taskViewModel.quickEntryText, lists: lists)
        let targetList = parsed.resolvedList(at: quickEntryListCandidateIndex)
            ?? parsed.detectedList
            ?? selectedList
        let title = parsed.cleanTitle.isEmpty ? taskViewModel.quickEntryText : parsed.cleanTitle

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        skipAddTaskDismiss = true
        withAnimation(SchemaMotion.smooth) {
            _ = taskViewModel.addTask(
                to: targetList,
                title: title,
                defaultWritableListID: listViewModel.defaultWritableListID,
                lists: lists,
                allTasks: allTasks,
                reminderTime: parsed.mergedReminderDate()
            )
        }
        quickEntryListCandidateIndex = 0
        isAddTaskExpanded = true
        DispatchQueue.main.async {
            isAddTaskFocused = true
            skipAddTaskDismiss = false
        }
    }

    private func closeAddTask() {
        taskViewModel?.quickEntryText = ""
        quickEntryListCandidateIndex = 0
        isAddTaskExpanded = false
        isAddTaskFocused = false
        skipAddTaskDismiss = false
        DispatchQueue.main.async {
            isTaskListFocused = true
        }
    }

    private func clearTaskSelection() {
        selectedTaskIDs = []
        primarySelectedTaskID = nil
        selectionAnchorID = nil
    }

    private func selectSingleTask(_ taskID: UUID) {
        selectedTaskIDs = [taskID]
        primarySelectedTaskID = taskID
        selectionAnchorID = taskID
    }

    private func selectAllPendingTasks(in incomplete: [SchemaTask]) {
        guard !incomplete.isEmpty else {
            clearTaskSelection()
            return
        }

        selectedTaskIDs = Set(incomplete.map(\.id))
        selectionAnchorID = incomplete.first?.id
        primarySelectedTaskID = incomplete.last?.id
        isTaskListFocused = true
    }

    private func enforceManualSortIfNeeded(listViewModel: ListViewModel) {
        guard RoutineSequenceOrdering.requiresManualSort(for: selectedList, in: allTasks) else {
            return
        }

        if listViewModel.sortOption != .manual {
            listViewModel.sortOption = .manual
        }
    }

    private func routineSequenceCandidates(for task: SchemaTask, in tasks: [SchemaTask]) -> [SchemaTask] {
        guard let listID = task.list?.id else { return [] }

        return tasks.filter { candidate in
            candidate.id != task.id
                && candidate.isRoutine
                && candidate.list?.id == listID
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func openTaskDetail(_ taskID: UUID) {
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return }

        taskDetailEditor = TaskDetailEditor(task: task)
        selectSingleTask(taskID)
        isTaskListFocused = false
    }

    private func closeTaskDetail() {
        taskDetailEditor = nil
        DispatchQueue.main.async {
            isTaskListFocused = true
        }
    }

    private func saveAndCloseTaskDetail(taskViewModel: TaskViewModel) {
        guard let editor = taskDetailEditor,
              let task = allTasks.first(where: { $0.id == editor.taskID }) else {
            closeTaskDetail()
            return
        }

        let parsed = AtMentionParser.commit(editor.draft.title, lists: lists)
        editor.draft.title = parsed.cleanTitle

        if let time = parsed.detectedTime {
            editor.draft.selectedTime = time
        }

        if let date = parsed.detectedDate, !editor.draft.isRoutine {
            editor.draft.selectedDate = date
        }

        if let list = parsed.resolvedList(at: editor.selectedListCandidateIndex) {
            taskViewModel.moveTask(task, to: list, allTasks: allTasks)
        }

        let draft = editor.draft
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            closeTaskDetail()
            return
        }

        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue = description.isEmpty ? nil : description
        let reminder = draft.computedReminderDate

        Task {
            if let failure = await taskViewModel.applyDetailChanges(
                task,
                title: title,
                description: descriptionValue,
                reminder: reminder,
                isRoutine: draft.isRoutine,
                routineDays: draft.normalizedRoutineDays,
                afterTaskID: draft.afterTaskID,
                allTasks: allTasks
            ) {
                sequenceValidationAlert = failure
                return
            }
            await refreshNotifications()
            closeTaskDetail()
        }
    }

    private func moveSingleTaskSelection(by offset: Int, in navigableTaskIDs: [UUID]) {
        guard !isEditingListName else { return }
        guard !navigableTaskIDs.isEmpty else {
            clearTaskSelection()
            return
        }

        let currentID = primarySelectedTaskID ?? selectedTaskIDs.first

        if currentID == nil {
            selectSingleTask(navigableTaskIDs[0])
            isTaskListFocused = true
            return
        }

        guard let currentIndex = navigableTaskIDs.firstIndex(of: currentID!) else {
            selectSingleTask(navigableTaskIDs[0])
            isTaskListFocused = true
            return
        }

        let nextIndex = max(0, min(navigableTaskIDs.count - 1, currentIndex + offset))
        selectSingleTask(navigableTaskIDs[nextIndex])
        isTaskListFocused = true
    }

    private func handleKeyboardToggleSelected(
        taskIDs: Set<UUID>,
        incomplete: [SchemaTask],
        completed: [SchemaTask],
        taskViewModel: TaskViewModel
    ) {
        let allTasks = incomplete + completed
        let selectedTasks = allTasks.filter { taskIDs.contains($0.id) }
        let tasksToCheckOff = selectedTasks.filter { !$0.isCompleted }
        let tasksToUncheck = selectedTasks.filter(\.isCompleted)

        withAnimation(SchemaMotion.smooth) {
            let visibleTasks = incomplete + completed
            for task in tasksToCheckOff + tasksToUncheck {
                taskViewModel.toggleCompletion(task, in: visibleTasks)
            }
        }

        if tasksToCheckOff.count == 1, tasksToUncheck.isEmpty,
           let task = tasksToCheckOff.first,
           let currentIndex = incomplete.firstIndex(where: { $0.id == task.id }) {
            let remaining = incomplete.filter { $0.id != task.id }
            if remaining.isEmpty {
                clearTaskSelection()
            } else {
                selectSingleTask(remaining[min(currentIndex, remaining.count - 1)].id)
            }
        } else if tasksToUncheck.count == 1, tasksToCheckOff.isEmpty,
                  let task = tasksToUncheck.first {
            selectSingleTask(task.id)
        } else if !tasksToCheckOff.isEmpty {
            let checkedIDs = Set(tasksToCheckOff.map(\.id))
            let remaining = incomplete.filter { !checkedIDs.contains($0.id) }
            if let firstRemaining = remaining.first {
                selectSingleTask(firstRemaining.id)
            } else {
                clearTaskSelection()
            }
        } else {
            clearTaskSelection()
        }

        isTaskListFocused = true
    }

    private func handleKeyboardDeleteSelected(
        taskIDs: Set<UUID>,
        navigableTaskIDs: [UUID],
        incomplete: [SchemaTask],
        completed: [SchemaTask],
        taskViewModel: TaskViewModel
    ) {
        let sortedIDsToDelete = navigableTaskIDs.filter { taskIDs.contains($0) }
        guard !sortedIDsToDelete.isEmpty else { return }

        let allTasks = incomplete + completed
        let firstDeletedIndex = navigableTaskIDs.firstIndex(of: sortedIDsToDelete[0])

        for taskID in sortedIDsToDelete.reversed() {
            guard let task = allTasks.first(where: { $0.id == taskID }) else { continue }
            taskViewModel.deleteTask(task)
        }

        let remainingNavigable = navigableTaskIDs.filter { !taskIDs.contains($0) }
        if let firstDeletedIndex, !remainingNavigable.isEmpty {
            let nextIndex = min(firstDeletedIndex, remainingNavigable.count - 1)
            selectSingleTask(remainingNavigable[nextIndex])
        } else {
            clearTaskSelection()
        }

        isTaskListFocused = true
    }

    private func handleKeyboardDuplicateSelected(
        taskIDs: Set<UUID>,
        incomplete: [SchemaTask],
        completed: [SchemaTask],
        taskViewModel: TaskViewModel
    ) {
        let orderedTasks = (incomplete + completed).filter { taskIDs.contains($0.id) }
        guard !orderedTasks.isEmpty else { return }

        withAnimation(SchemaMotion.smooth) {
            let copies = taskViewModel.duplicateTasks(orderedTasks, allTasks: allTasks)
            if !copies.isEmpty {
                selectedTaskIDs = Set(copies.map(\.id))
                primarySelectedTaskID = copies.last?.id
                selectionAnchorID = copies.first?.id
            }
        }

        isTaskListFocused = true
    }

    private func dismissActiveEditing(taskViewModel: TaskViewModel) {
        if isAddTaskExpanded {
            closeAddTask()
        }
        if taskDetailEditor != nil {
            saveAndCloseTaskDetail(taskViewModel: taskViewModel)
            return
        }
        clearTaskSelection()
    }

    private func handleNotificationSelect(_ item: SchemaNotificationItem, listViewModel: ListViewModel) {
        if let listID = item.listID {
            listViewModel.selectedListID = listID
        }
        highlightedTaskID = item.taskID
        showNotifications = false
    }

    private func refreshNotifications() async {
        notificationItems = await notificationService.fetchPendingReminders()
    }

    private func handleTaskMove(
        source: IndexSet,
        destination: Int,
        incomplete: [SchemaTask],
        taskViewModel: TaskViewModel,
        listViewModel: ListViewModel
    ) {
        if listViewModel.sortOption != .manual {
            withAnimation(SchemaMotion.smooth) {
                listViewModel.sortOption = .manual
            }
        }

        withAnimation(SchemaMotion.smooth) {
            _ = taskViewModel.moveTasks(
                from: source,
                to: destination,
                in: incomplete,
                allTasks: allTasks
            )
        }
    }

    private func removeFollowerTimesFromDetailEditor(taskViewModel: TaskViewModel) {
        guard let editor = taskDetailEditor else { return }

        let followerIDs = RoutineSequenceOrdering.followerIDsInProposedChain(
            containing: editor.taskID,
            title: editor.draft.title,
            isRoutine: editor.draft.isRoutine,
            afterTaskID: editor.draft.afterTaskID,
            reminderTime: editor.draft.computedReminderDate,
            in: allTasks
        )

        guard !followerIDs.isEmpty else { return }

        if followerIDs.contains(editor.taskID) {
            editor.draft.clearReminder()
        }

        let otherFollowerIDs = followerIDs.filter { $0 != editor.taskID }
        sequenceValidationAlert = nil

        Task {
            if !otherFollowerIDs.isEmpty {
                await taskViewModel.clearReminderTimes(for: otherFollowerIDs, in: allTasks)
                await refreshNotifications()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SchemaList.self, SchemaTask.self], inMemory: true)
}

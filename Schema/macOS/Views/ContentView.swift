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
    @State private var notificationItems: [SchemaNotificationItem] = []
    @State private var isAddTaskExpanded = false
    @State private var skipAddTaskDismiss = false
    @State private var editingTaskID: UUID?
    @FocusState private var isAddTaskFocused: Bool

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
                        notificationService: notificationService
                    )
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
        VStack(spacing: 0) {
            ListContextBar(
                onAllLists: {
                    navigationPath.append(WorkspaceRoute.allLists)
                },
                listViewModel: listViewModel
            )

            ListNavigationBar(
                lists: lists,
                selectedListID: listViewModel.selectedListID,
                taskCount: taskCount,
                onSelect: { list in
                    withAnimation(SchemaMotion.smooth) {
                        listViewModel.selectList(list)
                    }
                }
            )

            AddTaskBar(
                text: Binding(
                    get: { taskViewModel.quickEntryText },
                    set: { taskViewModel.quickEntryText = $0 }
                ),
                isExpanded: $isAddTaskExpanded,
                placeholder: quickEntryPlaceholder,
                onSubmit: {
                    submitQuickEntry(taskViewModel: taskViewModel, listViewModel: listViewModel)
                },
                onCancel: closeAddTask,
                focusBinding: $isAddTaskFocused
            )

            TaskListView(
                incompleteTasks: taskViewModel.incompleteTasks(
                    for: selectedList,
                    from: allTasks,
                    sortOption: listViewModel.sortOption,
                    filterOption: listViewModel.filterOption
                ),
                completedTasks: taskViewModel.completedTasks(
                    for: selectedList,
                    from: allTasks,
                    sortOption: listViewModel.sortOption,
                    filterOption: listViewModel.filterOption
                ),
                highlightedTaskID: highlightedTaskID,
                showListTags: selectedList?.isEverythingList == true,
                selectedListID: listViewModel.selectedListID,
                editingTaskID: editingTaskID,
                sortOption: listViewModel.sortOption,
                filterOption: listViewModel.filterOption,
                onToggle: { task in
                    withAnimation(SchemaMotion.smooth) {
                        taskViewModel.toggleCompletion(task)
                    }
                },
                onDelete: { task in
                    taskViewModel.deleteTask(task)
                },
                onUpdateTitle: { task, title in
                    taskViewModel.updateTitle(task, title: title)
                },
                onSetReminder: { task, date in
                    Task {
                        await taskViewModel.setReminder(task, at: date)
                        await refreshNotifications()
                    }
                },
                onEditingTaskIDChange: { taskID in
                    editingTaskID = taskID
                }
            )
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(SchemaTheme.background)
        .clickOutsideDismiss(isActive: isAddTaskExpanded || editingTaskID != nil) {
            dismissActiveEditing()
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

        Task {
            await notificationService.rescheduleAllReminders(for: allTasks)
            await refreshNotifications()
        }
    }

    private func submitQuickEntry(taskViewModel: TaskViewModel, listViewModel: ListViewModel) {
        guard !taskViewModel.quickEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        skipAddTaskDismiss = true
        withAnimation(SchemaMotion.smooth) {
            _ = taskViewModel.addTask(
                to: selectedList,
                title: taskViewModel.quickEntryText,
                defaultWritableListID: listViewModel.defaultWritableListID,
                lists: lists
            )
        }
        isAddTaskExpanded = true
        DispatchQueue.main.async {
            isAddTaskFocused = true
            skipAddTaskDismiss = false
        }
    }

    private func closeAddTask() {
        taskViewModel?.quickEntryText = ""
        isAddTaskExpanded = false
        isAddTaskFocused = false
        skipAddTaskDismiss = false
    }

    private func dismissActiveEditing() {
        if isAddTaskExpanded {
            closeAddTask()
        }
        editingTaskID = nil
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
}

#Preview {
    ContentView()
        .modelContainer(for: [SchemaList.self, SchemaTask.self], inMemory: true)
}

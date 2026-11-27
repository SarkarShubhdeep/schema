//
//  ContentView.swift
//  Schema
//

import SwiftUI
import SwiftData

/// Window root: creates the view models and workspace state, then hosts the
/// workspace, or the Settings page in its place (#108).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    /// Pages and tasks, fetched again only when one is added or removed
    /// (#45; see ModelStore). `@Query` fetched every task on each keystroke.
    @State private var listStore: ModelStore<SchemaList>?
    @State private var taskStore: ModelStore<SchemaTask>?

    private var lists: [SchemaList] {
        (listStore?.items ?? []).sorted { $0.order < $1.order }
    }

    /// Unsorted: every view sorts what it shows.
    private var allTasks: [SchemaTask] {
        taskStore?.items ?? []
    }

    @State private var listViewModel: ListViewModel?
    @State private var taskViewModel: TaskViewModel?
    @State private var workspace = WorkspaceState()
    /// Keeps Pomodoro timers moving while the app runs (#89).
    @State private var pomodoro: PomodoroRunner?

    private let notificationService = NotificationService()

    var body: some View {
        Group {
            if let listViewModel, let taskViewModel {
                workspaceStack(listViewModel: listViewModel, taskViewModel: taskViewModel)
            } else {
                ProgressView("Loading Schema...")
                    .frame(minWidth: 720, minHeight: 520)
            }
        }
        .environment(workspace)
        .environment(workspace.navigation)
        .environment(pomodoro)
        .task(id: pomodoro == nil) {
            await pomodoro?.run()
        }
        .onAppear(perform: bootstrapIfNeeded)
        .onReceive(NotificationCenter.default.publisher(for: NotificationNames.taskReminderOpened)) { notification in
            if let listID = notification.openedListID {
                listViewModel?.selectList(id: listID, from: lists)
            }
            workspace.highlightedTaskID = notification.openedTaskID
        }
        .onChange(of: lists.count) { _, _ in
            ensureListSelection()
        }
    }

    private func openNotification(_ item: SchemaNotificationItem, listViewModel: ListViewModel) {
        if let listID = item.listID {
            listViewModel.selectList(id: listID, from: lists)
        }
        workspace.highlightedTaskID = item.taskID
        workspace.showNotifications = false
    }

    @ViewBuilder
    private func workspaceStack(listViewModel: ListViewModel, taskViewModel: TaskViewModel) -> some View {
        Group {
            if workspace.showSettings {
                SettingsScreen(listViewModel: listViewModel, lists: lists, notificationService: notificationService)
                    .frame(minWidth: ShellMetrics.minimumWindowWidth, minHeight: 520)
            } else {
                appStack(listViewModel: listViewModel, taskViewModel: taskViewModel)
            }
        }
        // The window controls sit in the sidebar's header row (#116).
        .background(WindowControlsPlacement())
        .focusedSceneValue(\.workspaceState, workspace)
    }

    private func appStack(listViewModel: ListViewModel, taskViewModel: TaskViewModel) -> some View {
        @Bindable var workspace = workspace

        return HStack(spacing: ShellMetrics.margin) {
            if !workspace.isSidebarCollapsed {
                SidebarView(lists: lists, allTasks: allTasks, listViewModel: listViewModel, onNotificationSelect: { item in
                    openNotification(item, listViewModel: listViewModel)
                })
                .transition(SchemaMotion.moving(.move(edge: .leading).combined(with: .opacity)))
            }

            WorkspaceView(
                lists: lists,
                allTasks: allTasks,
                listViewModel: listViewModel,
                taskViewModel: taskViewModel,
                notificationService: notificationService
            )
            .frame(minWidth: ShellMetrics.mainMinWidth, maxWidth: .infinity)
        }
        .padding(ShellMetrics.margin)
        // Collapsed, the sidebar is a pill at the top left beside the page's header (#116).
        .overlay(alignment: .topLeading) {
            if workspace.isSidebarCollapsed {
                SidebarPill()
                    .padding(ShellMetrics.margin)
                    .transition(SchemaMotion.followingPanel(.opacity.combined(with: .offset(x: -8))))
            }
        }
        .environment(\.shellHeaderInsets, ShellHeaderInsets(
            leading: workspace.isSidebarCollapsed ? ShellMetrics.collapsedSidebarWidth + ShellMetrics.margin : 0,
            trailing: 0
        ))
        .background(SchemaTheme.canvas)
        .ignoresSafeArea()
        .frame(minWidth: ShellMetrics.minimumWindowWidth, minHeight: 520)
        .overlay {
            if let ids = workspace.pendingDeleteIDs {
                DeleteConfirmationDialog(
                    taskCount: ids.count,
                    onCancel: workspace.cancelPendingDelete,
                    onConfirm: workspace.confirmPendingDelete
                )
            } else if let id = workspace.pendingPageDeleteID,
                      let page = lists.first(where: { $0.id == id }) {
                DeleteConfirmationDialog(
                    page: page,
                    onCancel: workspace.cancelPendingPageDelete,
                    onConfirm: workspace.confirmPendingPageDelete
                )
            }
        }
        .overlay {
            if listViewModel.showNewListSheet {
                NewPageDialog(
                    title: Binding(get: { listViewModel.newListTitle }, set: { listViewModel.newListTitle = $0 }),
                    kind: Binding(get: { listViewModel.newPageKind }, set: { listViewModel.newPageKind = $0 }),
                    shortcutNumber: newPageShortcutNumber(listViewModel),
                    onCreate: {
                        listViewModel.createList(
                            title: listViewModel.newListTitle,
                            kind: listViewModel.newPageKind,
                            existingLists: lists
                        )
                    },
                    onCancel: listViewModel.cancelNewPage
                )
            }
        }
        .animation(SchemaMotion.appear, value: workspace.isConfirmingDelete)
        .animation(SchemaMotion.appear, value: listViewModel.showNewListSheet)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            workspace.windowWidthChanged(to: width)
        }
        .task {
            await workspace.refreshNotifications(using: notificationService)
        }
        .onChange(of: workspace.showNotifications) { _, isShowing in
            if isShowing {
                Task { await workspace.refreshNotifications(using: notificationService) }
            }
        }
        .onChange(of: allTasks.count) { _, _ in
            Task { await workspace.refreshNotifications(using: notificationService) }
        }
    }

    /// ⌘1–⌘9 go to the first nine pages; the new page is added last.
    private func newPageShortcutNumber(_ listViewModel: ListViewModel) -> Int? {
        let next = listViewModel.pages(from: lists).count + 1
        return next <= 9 ? next : nil
    }

    private func bootstrapIfNeeded() {
        guard listViewModel == nil else { return }

        // Notes 0.5.1 left out of sight on tasks that also had a body (#84).
        PageDocumentMigration.moveLeftoverNotes(in: modelContext)
        let loadedLists = ModelStore<SchemaList>(context: modelContext)
        listStore = loadedLists
        let loadedTasks = ModelStore<SchemaTask>(context: modelContext)
        taskStore = loadedTasks
        let listVM = ListViewModel(modelContext: modelContext, navigation: workspace.navigation)
        // Read the fetched pages directly: this must never see an empty
        // store by mistake, or it would add the default pages again.
        listVM.ensureDefaultListsIfNeeded(from: loadedLists.items.sorted { $0.order < $1.order })
        listViewModel = listVM
        pomodoro = PomodoroRunner(context: modelContext)
        ensureListSelection()
        #if DEBUG
        if DemoData.isEnabled, DemoData.opensToday {
            listVM.selectSmartView(.today, from: lists)
        }
        if DemoData.isEnabled, DemoData.opensPomodoro {
            listVM.selectPomodoro(from: lists)
        }
        if DemoData.isEnabled, DemoData.opensUpcoming {
            listVM.selectSmartView(.upcoming, from: lists)
        }
        if DemoData.isEnabled, let spot = DemoData.rightClickSpot {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                SchemaMenuPresenter.rightClickForDemo(atFraction: spot)
                Task { await SchemaMenuPresenter.shared.runDemo() }
            }
        }
        if DemoData.isEnabled, DemoData.runsBenchmark {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [lists, modelContext] in
                DemoBenchmark.run(lists: lists, listViewModel: listVM, workspace: workspace, context: modelContext)
            }
        }
        if DemoData.isEnabled, DemoData.togglesSidebar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [workspace] in
                workspace.toggleSidebar()
            }
        }
        if DemoData.isEnabled, DemoData.opensSettings || DemoData.settingsQuery != nil || DemoData.settingsSection != nil {
            workspace.openSettings(DemoData.settingsSection)
        }
        if DemoData.isEnabled, DemoData.opensNewPage {
            listVM.openNewPage()
            listVM.newListTitle = "Side project ideas"
            listVM.newPageKind = .scratchpad
        }
        if DemoData.isEnabled, DemoData.opensScratchpad {
            // With the large pages, open the 500-block Journal instead of Ideas.
            let scratchpads = listVM.pages(from: lists).filter(\.isScratchpad)
            listVM.selectList(DemoData.seedsLargePages ? scratchpads.first { $0.title == "Journal" } : scratchpads.first)
        }
        if DemoData.isEnabled, DemoData.opensTagPage {
            listVM.selectList(listVM.tagPages(from: lists).first)
        }
        if DemoData.isEnabled, DemoData.opensFirstPage {
            listVM.selectList(listVM.pages(from: lists).first)
        }
        if DemoData.isEnabled, DemoData.opensPageDelete, let page = listVM.pages(from: lists).first {
            listVM.selectList(page)
            workspace.requestPageDelete(page.id)
        }
        if DemoData.isEnabled, DemoData.renamesPage, let id = listVM.selectedListID {
            workspace.requestPageRename(id)
        }
        if DemoData.isEnabled, DemoData.selectsTasks || DemoData.opensDeleteDialog {
            let ids = allTasks
                .filter { !$0.isCompleted && (listVM.selectedListID == nil || $0.list?.id == listVM.selectedListID) }
                .prefix(2)
                .map(\.id)
            workspace.select(Array(ids))
            if DemoData.opensDeleteDialog {
                workspace.requestDelete(Set(ids))
            }
        }
        if DemoData.isEnabled, DemoData.opensTaskDetail,
           let task = allTasks.first(where: { !$0.isCompleted && $0.displayDescription != nil && $0.reminderTime != nil }) {
            workspace.selectSingle(task.id)
            workspace.taskDetailEditor = TaskDetailEditor(task: task)
        }
        if DemoData.isEnabled, DemoData.opensRoutineTask,
           let task = allTasks.first(where: { $0.isRoutine && !$0.isCompleted }) {
            task.routineDays = [2, 3, 5, 6, 7, 1]
            workspace.selectSingle(task.id)
            workspace.taskDetailEditor = TaskDetailEditor(task: task)
        }
        #endif

        taskViewModel = TaskViewModel(
            modelContext: modelContext,
            notificationService: notificationService
        )

        RoutineResetService(modelContext: modelContext)
            .resetRoutineTasksIfNeeded(tasks: loadedTasks.items)

        Task {
            await notificationService.rescheduleAllReminders(for: loadedTasks.items)
            await workspace.refreshNotifications(using: notificationService)
        }
    }

    private func ensureListSelection() {
        guard let listViewModel else { return }
        // A page that is gone (deleted elsewhere) leaves for Today.
        if let id = listViewModel.selectedListID, !lists.contains(where: { $0.id == id }) {
            listViewModel.navigation.forget(page: id)
        }
        if listViewModel.defaultWritableListID == nil {
            listViewModel.defaultWritableListID = lists.first(where: \.acceptsTasks)?.id
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SchemaList.self, SchemaTask.self, SchemaBlock.self], inMemory: true)
}

//
//  ContentView.swift
//  Schema
//

import SwiftUI
import SwiftData

/// Window root: creates the view models and workspace state, then hosts the
/// workspace with its toolbar, settings sheet, and navigation.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SchemaList.order) private var lists: [SchemaList]
    @Query(sort: \SchemaTask.createdAt) private var allTasks: [SchemaTask]

    @State private var listViewModel: ListViewModel?
    @State private var taskViewModel: TaskViewModel?
    @State private var workspace = WorkspaceState()

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
        .onAppear(perform: bootstrapIfNeeded)
        .onReceive(NotificationCenter.default.publisher(for: NotificationNames.taskReminderOpened)) { notification in
            if let listID = notification.openedListID {
                listViewModel?.selectedListID = listID
            }
            workspace.highlightedTaskID = notification.openedTaskID
        }
        .onChange(of: lists.count) { _, _ in
            ensureListSelection()
        }
    }

    private func openNotification(_ item: SchemaNotificationItem, listViewModel: ListViewModel) {
        if let listID = item.listID {
            listViewModel.selectedListID = listID
        }
        workspace.highlightedTaskID = item.taskID
        workspace.showNotifications = false
    }

    private func workspaceStack(listViewModel: ListViewModel, taskViewModel: TaskViewModel) -> some View {
        @Bindable var workspace = workspace

        return HStack(spacing: 0) {
            if !workspace.isSidebarCollapsed {
                SidebarView(lists: lists, allTasks: allTasks, listViewModel: listViewModel, onNotificationSelect: { item in
                    openNotification(item, listViewModel: listViewModel)
                })
                .transition(SchemaMotion.moving(.move(edge: .leading)))
            }

            WorkspaceView(
                lists: lists,
                allTasks: allTasks,
                listViewModel: listViewModel,
                taskViewModel: taskViewModel,
                notificationService: notificationService
            )
            .frame(minWidth: ShellMetrics.mainMinWidth + ShellMetrics.detailsRailWidth, maxWidth: .infinity)
            .clipped()
        }
        .background(SchemaTheme.canvas.ignoresSafeArea())
        // Collapsed, the sidebar is a floating bar over the main column (#43).
        .overlay(alignment: .topLeading) {
            if workspace.isSidebarCollapsed {
                FloatingSidebarBar(lists: lists, listViewModel: listViewModel, onNotificationSelect: { item in
                    openNotification(item, listViewModel: listViewModel)
                })
                    .transition(SchemaMotion.followingPanel(.opacity.combined(with: .offset(x: -8))))
            }
        }
        .overlay(alignment: .topTrailing) {
            DetailsPanelTitleBarStrip()
        }
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
        .focusedSceneValue(\.workspaceState, workspace)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            workspace.windowWidthChanged(to: width)
        }
        .sheet(isPresented: $workspace.showSettings) {
            SettingsView(
                listViewModel: listViewModel,
                lists: lists,
                notificationService: notificationService,
                allowIndependentFollowerRoutineCompletion: $workspace.allowIndependentFollowerRoutineCompletion,
                weekStart: $workspace.weekStart
            )
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

        let listVM = ListViewModel(modelContext: modelContext)
        listVM.ensureDefaultListsIfNeeded(from: lists)
        listViewModel = listVM
        ensureListSelection()
        #if DEBUG
        if DemoData.isEnabled, DemoData.opensToday {
            listVM.selectSmartView(.today, from: lists)
        }
        if DemoData.isEnabled, DemoData.opensUpcoming {
            listVM.selectSmartView(.upcoming, from: lists)
        }
        if DemoData.isEnabled, DemoData.togglesSidebar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [workspace] in
                workspace.toggleSidebar()
            }
        }
        if DemoData.isEnabled, DemoData.opensSettings {
            workspace.showSettings = true
        }
        if DemoData.isEnabled, DemoData.opensNewPage {
            listVM.openNewPage()
            listVM.newListTitle = "Side project ideas"
            listVM.newPageKind = .scratchpad
        }
        if DemoData.isEnabled, DemoData.opensScratchpad {
            listVM.selectList(listVM.pages(from: lists).first(where: \.isScratchpad))
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
                .filter { !$0.isCompleted && $0.list?.id == listVM.selectedListID }
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
            .resetRoutineTasksIfNeeded(tasks: allTasks)

        Task {
            await notificationService.rescheduleAllReminders(for: allTasks)
            await workspace.refreshNotifications(using: notificationService)
        }
    }

    private func ensureListSelection() {
        guard let listViewModel else { return }
        if listViewModel.selectedListID == nil {
            listViewModel.selectedListID = lists.first?.id
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

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

    private func workspaceStack(listViewModel: ListViewModel, taskViewModel: TaskViewModel) -> some View {
        @Bindable var workspace = workspace

        return HStack(spacing: 0) {
            SidebarView(lists: lists, allTasks: allTasks, listViewModel: listViewModel, onNotificationSelect: { item in
                if let listID = item.listID {
                    listViewModel.selectedListID = listID
                }
                workspace.highlightedTaskID = item.taskID
                workspace.showNotifications = false
            })

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
        .overlay(alignment: .topTrailing) {
            DetailsPanelTitleBarStrip()
        }
        .frame(minWidth: ShellMetrics.minimumWindowWidth, minHeight: 520)
        .overlay {
            if let ids = workspace.pendingDeleteIDs {
                DeleteConfirmationDialog(
                    count: ids.count,
                    onCancel: workspace.cancelPendingDelete,
                    onConfirm: workspace.confirmPendingDelete
                )
            }
        }
        .animation(SchemaMotion.fast, value: workspace.isConfirmingDelete)
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
        if DemoData.isEnabled, DemoData.opensSettings {
            workspace.showSettings = true
        }
        if DemoData.isEnabled, DemoData.opensFirstPage {
            listVM.selectList(listVM.pages(from: lists).first)
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
            listViewModel.defaultWritableListID = lists.first(where: { !$0.isEverythingList })?.id
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SchemaList.self, SchemaTask.self], inMemory: true)
}

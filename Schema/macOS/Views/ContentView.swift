//
//  ContentView.swift
//  Schema
//

import SwiftUI
import SwiftData

enum WorkspaceRoute: Hashable {
    case allLists
}

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

        return NavigationStack(path: $workspace.navigationPath) {
            WorkspaceView(
                lists: lists,
                allTasks: allTasks,
                listViewModel: listViewModel,
                taskViewModel: taskViewModel,
                notificationService: notificationService
            )
            .navigationDestination(for: WorkspaceRoute.self) { route in
                switch route {
                case .allLists:
                    AllListsView(
                        lists: lists,
                        listViewModel: listViewModel,
                        onSelectList: { list in
                            listViewModel.selectList(list)
                            workspace.navigationPath = NavigationPath()
                        }
                    )
                }
            }
        }
        .schemaWindowToolbar()
        .toolbar {
            AppHeaderToolbar(
                showNotifications: $workspace.showNotifications,
                showSettings: $workspace.showSettings,
                pendingNotificationCount: workspace.notificationItems.count,
                notificationItems: workspace.notificationItems,
                onNotificationSelect: { item in
                    if let listID = item.listID {
                        listViewModel.selectedListID = listID
                    }
                    workspace.highlightedTaskID = item.taskID
                    workspace.showNotifications = false
                }
            )
        }
        .sheet(isPresented: $workspace.showSettings) {
            SettingsView(
                listViewModel: listViewModel,
                lists: lists,
                notificationService: notificationService,
                allowIndependentFollowerRoutineCompletion: $workspace.allowIndependentFollowerRoutineCompletion
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

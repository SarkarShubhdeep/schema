//
//  ContentView.swift
//  Schema
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SchemaList.order) private var lists: [SchemaList]
    @Query(sort: \SchemaTask.createdAt) private var allTasks: [SchemaTask]

    @State private var listViewModel: ListViewModel?
    @State private var taskViewModel: TaskViewModel?
    @FocusState private var isQuickEntryFocused: Bool

    private var selectedList: SchemaList? {
        listViewModel?.selectedList(from: lists)
    }

    var body: some View {
        Group {
            if let listViewModel, let taskViewModel {
                mainContent(listViewModel: listViewModel, taskViewModel: taskViewModel)
            } else {
                ProgressView("Loading Schema...")
                    .frame(minWidth: 720, minHeight: 520)
            }
        }
        .onAppear {
            if listViewModel == nil {
                let listVM = ListViewModel(modelContext: modelContext)
                listVM.ensureDefaultListsIfNeeded(from: lists)
                if listVM.selectedListID == nil {
                    listVM.selectedListID = lists.first?.id
                }
                listViewModel = listVM
                taskViewModel = TaskViewModel(modelContext: modelContext)
            }
        }
        .onChange(of: lists.count) { _, _ in
            if listViewModel?.selectedListID == nil {
                listViewModel?.selectedListID = lists.first?.id
            }
        }
    }

    @ViewBuilder
    private func mainContent(
        listViewModel: ListViewModel,
        taskViewModel: TaskViewModel
    ) -> some View {
        VStack(spacing: 0) {
            ListNavigationBar(
                lists: lists,
                selectedListID: listViewModel.selectedListID,
                onSelect: { list in
                    listViewModel.selectList(list)
                },
                onCreateList: {
                    listViewModel.showNewListSheet = true
                }
            )

            Divider()
                .overlay(SchemaTheme.divider)

            TaskListView(
                incompleteTasks: taskViewModel.incompleteTasks(for: selectedList, from: allTasks),
                completedTasks: taskViewModel.completedTasks(for: selectedList, from: allTasks),
                onToggle: { task in
                    taskViewModel.toggleCompletion(task)
                },
                onDelete: { task in
                    taskViewModel.deleteTask(task)
                },
                onSetReminder: { task, date in
                    Task {
                        await taskViewModel.setReminder(task, at: date)
                    }
                }
            )

            QuickEntryField(
                text: Binding(
                    get: { taskViewModel.quickEntryText },
                    set: { taskViewModel.quickEntryText = $0 }
                ),
                placeholder: quickEntryPlaceholder,
                onSubmit: {
                    submitQuickEntry(taskViewModel: taskViewModel)
                },
                focusBinding: $isQuickEntryFocused
            )
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(SchemaTheme.background)
        .workspaceKeyboardShortcuts(
            isQuickEntryFocused: $isQuickEntryFocused,
            lists: lists,
            onSelectListAtIndex: { index in
                listViewModel.selectList(at: index, from: lists)
            },
            onCreateList: {
                listViewModel.showNewListSheet = true
            },
            onSubmitQuickEntry: {
                submitQuickEntry(taskViewModel: taskViewModel)
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

    private func submitQuickEntry(taskViewModel: TaskViewModel) {
        guard !taskViewModel.quickEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        _ = taskViewModel.addTask(to: selectedList, title: taskViewModel.quickEntryText)
        isQuickEntryFocused = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SchemaList.self, SchemaTask.self], inMemory: true)
}

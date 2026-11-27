//
//  WorkspaceView+Actions.swift
//  Schema
//

import SwiftUI

extension WorkspaceView {
    // MARK: Quick entry

    func submitQuickEntry() {
        let text = taskViewModel.quickEntryText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let parsed = AtMentionParser.commit(text, lists: lists)
        let targetList = parsed.resolvedList(at: workspace.quickEntryListCandidateIndex)
            ?? parsed.detectedList
            ?? selectedList
        let title = parsed.cleanTitle.isEmpty ? text : parsed.cleanTitle
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

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
        workspace.quickEntryListCandidateIndex = 0
        workspace.isAddTaskExpanded = true
        workspace.requestFocus(.addTask)
    }

    func closeAddTask() {
        taskViewModel.quickEntryText = ""
        workspace.quickEntryListCandidateIndex = 0
        workspace.isAddTaskExpanded = false
        workspace.requestFocus(.taskList)
    }

    func moveSelectionFromAddTask(by offset: Int, in navigableTaskIDs: [UUID]) {
        guard !workspace.isEditingListName else { return }
        workspace.moveSelection(by: offset, in: navigableTaskIDs)
        workspace.requestFocus(.taskList)
    }

    // MARK: Row actions

    func toggleCompletion(_ task: SchemaTask) {
        withAnimation(SchemaMotion.smooth) {
            taskViewModel.toggleCompletion(task, in: allTasks)
        }
    }

    func setReminder(_ task: SchemaTask, _ date: Date?) {
        Task {
            await taskViewModel.setReminder(task, at: date)
            await refreshNotifications()
        }
    }

    func reorderTask(_ taskID: UUID, toInsertionIndex index: Int) {
        let displayed = incompleteTasks
        guard taskViewModel.reorder(taskID: taskID, toInsertionIndex: index, in: displayed) else { return }

        // Reassigning sort slots makes the manual order match what was on
        // screen, so switching to Manual now keeps the dropped position.
        if listViewModel.sortOption != .manual {
            listViewModel.sortOption = .manual
        }
    }

    // MARK: Keyboard actions on the selection

    func toggleSelected(_ taskIDs: Set<UUID>) {
        let incomplete = incompleteTasks
        let visible = incomplete + completedTasks
        let selected = visible.filter { taskIDs.contains($0.id) }
        let checking = selected.filter { !$0.isCompleted }
        let unchecking = selected.filter(\.isCompleted)

        withAnimation(SchemaMotion.smooth) {
            for task in checking + unchecking {
                taskViewModel.toggleCompletion(task, in: visible)
            }
        }

        if !checking.isEmpty {
            workspace.selectNeighbor(afterRemoving: Set(checking.map(\.id)), from: incomplete.map(\.id))
        } else if unchecking.count == 1, let task = unchecking.first {
            workspace.selectSingle(task.id)
        } else {
            workspace.clearSelection()
        }
        workspace.requestFocus(.taskList)
    }

    /// Deletes a page and everything on it, after the dialog (#42).
    func deletePage(_ pageID: UUID) {
        guard let page = lists.first(where: { $0.id == pageID }), !page.isEverythingList else { return }
        if let editor = workspace.taskDetailEditor, page.tasks.contains(where: { $0.id == editor.taskID }) {
            closeTaskDetail()
        }
        workspace.clearSelection()
        // A tag page's #tags become plain words where they were used (#102).
        if page.isTagPage { TagPages.removeEverywhere(page, in: modelContext) }
        withAnimation(SchemaMotion.smooth) {
            taskViewModel.deleteTasks(onPage: page)
            listViewModel.deleteList(page, from: listViewModel.pages(from: lists))
        }
        Task { await refreshNotifications() }
    }

    func deleteSelected(_ taskIDs: Set<UUID>) {
        let visible = incompleteTasks + completedTasks
        let toDelete = visible.filter { taskIDs.contains($0.id) }
        guard !toDelete.isEmpty else { return }

        for task in toDelete.reversed() {
            taskViewModel.deleteTask(task)
        }
        workspace.selectNeighbor(afterRemoving: taskIDs, from: visible.map(\.id))
        workspace.requestFocus(.taskList)
    }

    /// Gives every selected task a new due date, keeping its time of day.
    func rescheduleSelected(to option: RescheduleOption) {
        let selected = (incompleteTasks + completedTasks).filter { workspace.isSelected($0.id) }
        guard !selected.isEmpty else { return }
        let now = Date.now
        Task {
            for task in selected {
                await taskViewModel.setReminder(task, at: option.date(keepingTimeOf: task.reminderTime, now: now))
            }
            await refreshNotifications()
        }
        workspace.requestFocus(.taskList)
    }

    /// Moves every selected task to `page`.
    func moveSelected(to page: SchemaList) {
        let selected = (incompleteTasks + completedTasks).filter { workspace.isSelected($0.id) }
        guard !selected.isEmpty else { return }
        withAnimation(SchemaMotion.smooth) {
            for task in selected {
                taskViewModel.moveTask(task, to: page, allTasks: allTasks)
            }
        }
        workspace.requestFocus(.taskList)
    }

    func duplicateSelected(_ taskIDs: Set<UUID>) {
        let ordered = (incompleteTasks + completedTasks).filter { taskIDs.contains($0.id) }
        guard !ordered.isEmpty else { return }

        withAnimation(SchemaMotion.smooth) {
            let copies = taskViewModel.duplicateTasks(ordered, allTasks: allTasks)
            if !copies.isEmpty {
                workspace.select(copies.map(\.id))
            }
        }
        workspace.requestFocus(.taskList)
    }

    func selectAllPending() {
        workspace.select(incompleteTasks.map(\.id))
        workspace.requestFocus(.taskList)
    }

    // MARK: Task page (#31)

    /// Opens the task as a page in the main column (#124): a step in back
    /// and forward, over the list or view it was opened from.
    func openTaskDetail(_ taskID: UUID) {
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return }
        workspace.taskDetailEditor = TaskDetailEditor(task: task)
        workspace.selectSingle(taskID)
        workspace.requestFocus(.none)
        listViewModel.go(to: .task(taskID))
    }

    /// Previous or next task on a task page: replaces this step.
    func stepTaskDetail(to taskID: UUID) {
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return }
        workspace.taskDetailEditor = TaskDetailEditor(task: task)
        workspace.selectSingle(taskID)
        listViewModel.navigation.replace(with: .task(taskID))
    }

    /// A mention chip (#81): the page, the task as a page, or the day on
    /// Today (for today) or Upcoming.
    func openMention(_ mention: EditorMention) {
        withAnimation(SchemaMotion.smooth) {
            switch mention {
            case .page(let id), .tag(let id):
                guard let page = lists.first(where: { $0.id == id }) else { return }
                listViewModel.selectList(page)
            case .task(let id):
                openTaskDetail(id)
            case .date(let date):
                let view: SmartView = Calendar.schema().isDateInToday(date) ? .today : .upcoming
                listViewModel.selectSmartView(view, from: lists)
            }
        }
    }

    /// A line on a tag page (#102): opens where it lives, a page or a task,
    /// with the caret on the line. A task tagged in its title opens as a page.
    func openTaggedLine(_ holderID: UUID, path: [Int]?, isTask: Bool) {
        withAnimation(SchemaMotion.smooth) {
            if let page = lists.first(where: { $0.id == holderID }) {
                listViewModel.selectList(page)
            } else if let task = allTasks.first(where: { $0.id == holderID }) {
                openTaskDetail(task.id)
            } else {
                return
            }
        }
        if let path, !path.isEmpty {
            workspace.revealRequest = EditorRevealRequest(key: holderID.uuidString, path: path)
        }
    }

    /// Up to the list or view under the task page (Esc), with the task
    /// still selected.
    func closeTaskDetail() {
        if listViewModel.destination.taskID != nil {
            listViewModel.go(to: listViewModel.context)
        }
        workspace.taskDetailEditor = nil
        workspace.requestFocus(.taskList)
    }

    /// Saves the Properties card's schedule (due, routine, after) to the task.
    func saveTaskSchedule() {
        guard let editor = workspace.taskDetailEditor,
              let task = allTasks.first(where: { $0.id == editor.taskID }) else { return }
        let draft = editor.draft
        Task {
            if let failure = await taskViewModel.applyDetailChanges(
                task,
                title: task.title,
                description: task.taskDescription,
                reminder: draft.computedReminderDate,
                isRoutine: draft.isRoutine,
                routineDays: draft.normalizedRoutineDays,
                afterTaskID: draft.afterTaskID,
                allTasks: allTasks
            ) {
                workspace.sequenceValidationAlert = failure
                return
            }
            await refreshNotifications()
        }
    }

    func removeFollowerTimesFromDetailEditor() {
        guard let editor = workspace.taskDetailEditor else { return }

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
        workspace.sequenceValidationAlert = nil

        Task {
            if !otherFollowerIDs.isEmpty {
                await taskViewModel.clearReminderTimes(for: otherFollowerIDs, in: allTasks)
            }
            saveTaskSchedule()
            await refreshNotifications()
        }
    }

    func routineSequenceCandidates(for task: SchemaTask) -> [SchemaTask] {
        guard let listID = task.list?.id else { return [] }

        return allTasks
            .filter { $0.id != task.id && $0.isRoutine && $0.list?.id == listID }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: Misc

    func dismissActiveEditing() {
        if workspace.isAddTaskExpanded {
            closeAddTask()
        }
        workspace.clearSelection()
    }

    func enforceManualSortIfNeeded() {
        guard RoutineSequenceOrdering.requiresManualSort(for: selectedList, in: allTasks),
              listViewModel.sortOption != .manual else { return }
        listViewModel.sortOption = .manual
    }

    func refreshNotifications() async {
        await workspace.refreshNotifications(using: notificationService)
    }
}

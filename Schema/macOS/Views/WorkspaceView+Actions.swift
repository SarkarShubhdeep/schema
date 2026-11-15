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

    // MARK: Detail panel

    func openTaskDetail(_ taskID: UUID) {
        guard let task = allTasks.first(where: { $0.id == taskID }) else { return }
        workspace.taskDetailEditor = TaskDetailEditor(task: task)
        workspace.selectSingle(taskID)
        workspace.requestFocus(.none)
    }

    func closeTaskDetail() {
        workspace.taskDetailEditor = nil
        workspace.requestFocus(.taskList)
    }

    func saveAndCloseTaskDetail() {
        guard let editor = workspace.taskDetailEditor,
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

        Task {
            if let failure = await taskViewModel.applyDetailChanges(
                task,
                title: title,
                description: description.isEmpty ? nil : description,
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
            closeTaskDetail()
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

        guard !otherFollowerIDs.isEmpty else { return }
        Task {
            await taskViewModel.clearReminderTimes(for: otherFollowerIDs, in: allTasks)
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
        if workspace.isDetailOpen {
            saveAndCloseTaskDetail()
            return
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

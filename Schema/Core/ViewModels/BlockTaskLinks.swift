//
//  BlockTaskLinks.swift
//  Schema
//
//  Make task from a line (#40). A line in a note can become a task in a
//  to-do list; the line stays in the note as a to-do linked to the task,
//  and checking either one checks both.
//

import Foundation

/// What the editor needs from the rest of the app to link lines to tasks.
/// The workspace supplies it, so the editor doesn't own task logic.
struct BlockTaskActions {
    /// To-do lists a task can go to, in sidebar order.
    var taskPages: [SchemaList]
    /// Where "Make task" puts a task without asking (Settings' default page).
    var defaultPage: SchemaList?
    var task: (UUID) -> SchemaTask?
    var makeTask: (_ title: String, _ page: SchemaList) -> SchemaTask?
    var toggleTask: (SchemaTask) -> Void
    var openTask: (SchemaTask) -> Void
    /// Move task to … on a linked to-do (#80).
    var moveTask: (SchemaTask, SchemaList) -> Void = { _, _ in }
}

extension BlockEditor {
    /// The task this line was made into, if it still exists.
    func linkedTask(for block: SchemaBlock, actions: BlockTaskActions?) -> SchemaTask? {
        guard let id = block.linkedTaskID, let actions else { return nil }
        return actions.task(id)
    }

    /// A line can become a task when it has text and isn't linked yet.
    func canMakeTask(from block: SchemaBlock, actions: BlockTaskActions?) -> Bool {
        guard let actions, !actions.taskPages.isEmpty, block.kind.holdsText else { return false }
        guard !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return linkedTask(for: block, actions: actions) == nil
    }

    /// Makes a task from the line in `page`; the line becomes a linked to-do.
    @discardableResult
    func makeTask(from block: SchemaBlock, in page: SchemaList, actions: BlockTaskActions) -> SchemaTask? {
        guard canMakeTask(from: block, actions: actions),
              let task = actions.makeTask(block.text, page) else { return nil }
        if block.kind != .todo { block.kind = .todo }
        block.linkedTaskID = task.id
        if block.isChecked, !task.isCompleted { actions.toggleTask(task) }
        block.updatedAt = .now
        saveChanges()
        return task
    }

    /// Open to-do lines that could still become tasks.
    func openToDosWithoutTasks(actions: BlockTaskActions?) -> [SchemaBlock] {
        blocks.filter { $0.kind == .todo && !$0.isChecked && canMakeTask(from: $0, actions: actions) }
    }

    /// Makes a task from every open to-do line on the page.
    func makeTasksFromOpenToDos(in page: SchemaList, actions: BlockTaskActions) -> Int {
        var made = 0
        for block in openToDosWithoutTasks(actions: actions) where makeTask(from: block, in: page, actions: actions) != nil {
            made += 1
        }
        return made
    }

    /// Checking a linked line checks its task too, and the other way round.
    func isChecked(_ block: SchemaBlock, actions: BlockTaskActions?) -> Bool {
        linkedTask(for: block, actions: actions)?.isCompleted ?? block.isChecked
    }

    func toggleChecked(_ block: SchemaBlock, actions: BlockTaskActions?) {
        if let task = linkedTask(for: block, actions: actions), let actions {
            actions.toggleTask(task)
            block.isChecked = task.isCompleted
            block.updatedAt = .now
            saveChanges()
        } else {
            toggleChecked(block)
        }
    }
}

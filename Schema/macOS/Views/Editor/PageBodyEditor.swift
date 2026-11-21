//
//  PageBodyEditor.swift
//  Schema
//
//  A page's or task's body in the TipTap editor (#77). Changes save to the
//  document as they arrive. On a scratchpad, a to-do made into a task stays
//  in step with it: ticking either ticks both.
//

import SwiftData
import SwiftUI

struct PageBodyEditor: View {
    /// Space left of the text, where the block handle goes (#78). Page
    /// headers indent by the same amount so their titles line up.
    static let gutterWidth: CGFloat = 32

    let holder: any PageDocumentHolder
    /// The page's or task's id: changes are saved by it.
    let id: UUID
    var taskActions: BlockTaskActions?
    var focusRequest: EditorFocusRequest?
    var onEscape: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        TipTapEditorView(
            documentJSON: displayJSON,
            documentKey: id.uuidString,
            focusRequest: focusRequest,
            onChange: save,
            onEscape: onEscape,
            taskContextJSON: taskContext.json,
            onMakeTask: makeTask,
            onOpenTask: { id in
                if let taskActions, let task = taskActions.task(id) { taskActions.openTask(task) }
            },
            onChangeDefaultPage: { openSettings() }
        )
    }

    /// The to-do pages a line can become a task in, and where each linked
    /// line's task lives (#80).
    private var taskContext: EditorTaskContext {
        guard let taskActions else { return EditorTaskContext() }
        let defaultID = (taskActions.defaultPage ?? taskActions.taskPages.first)?.id
        var context = EditorTaskContext()
        context.pages = taskActions.taskPages.map {
            .init(id: $0.id.uuidString, title: $0.title, isDefault: $0.id == defaultID)
        }
        for id in holder.linkedTaskIDs {
            if let task = taskActions.task(id) {
                context.tasks[id.uuidString] = .init(page: task.list?.title ?? "a page")
            }
        }
        return context
    }

    private func makeTask(text: String, pageID: UUID) -> UUID? {
        guard let taskActions, let page = taskActions.taskPages.first(where: { $0.id == pageID }) else { return nil }
        return taskActions.makeTask(text, page)?.id
    }

    /// The stored document, with linked to-dos ticked as their tasks are.
    private var displayJSON: String {
        let json = holder.documentJSON
        guard let taskActions else { return json }
        return PageDocument.applyingTaskStates(to: json) { taskActions.task($0)?.isCompleted }
    }

    private func save(_ json: String, key: String) {
        guard let target = key == id.uuidString ? holder : Self.holder(for: key, in: modelContext),
              target.setDocument(json) else { return }
        if let taskActions {
            for taskID in PageDocument.tasksToToggle(in: json, isDone: { taskActions.task($0)?.isCompleted }) {
                if let task = taskActions.task(taskID) { taskActions.toggleTask(task) }
            }
        }
        try? modelContext.save()
    }

    /// The page or task a change from before a switch belongs to.
    private static func holder(for key: String, in context: ModelContext) -> (any PageDocumentHolder)? {
        guard let id = UUID(uuidString: key) else { return nil }
        if let page = try? context.fetch(FetchDescriptor<SchemaList>(predicate: #Predicate { $0.id == id })).first {
            return page
        }
        return try? context.fetch(FetchDescriptor<SchemaTask>(predicate: #Predicate { $0.id == id })).first
    }
}

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
    /// On a tag page (#113): its synced blocks, what happens after each save
    /// (writing them back), and synced blocks removed or deleted by hand.
    var syncedBlocksJSON: String?
    var onSaved: ((_ json: String) -> Void)?
    var onSyncedRemoved: (([(holderID: UUID, blockID: String, kind: String)]) -> Void)?
    var onDeleteSynced: ((_ holderID: UUID, _ blockID: String, _ kind: String, _ source: String) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @Environment(\.editorMentionActions) private var mentionActions
    @Environment(WorkspaceState.self) private var workspace
    // What @ can mention (#81): every page and the open tasks.
    @Query(sort: \SchemaList.order) private var lists: [SchemaList]
    @Query(filter: #Predicate<SchemaTask> { !$0.isCompleted }, sort: \SchemaTask.createdAt, order: .reverse)
    private var openTasks: [SchemaTask]

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
            onMoveTask: { taskID, pageID in
                guard let taskActions, let task = taskActions.task(taskID),
                      let page = taskActions.taskPages.first(where: { $0.id == pageID }) else { return }
                taskActions.moveTask(task, page)
            },
            onChangeDefaultPage: { openSettings() },
            mentionContextJSON: mentionContext.json,
            onOpenMention: mentionActions.open,
            syncedBlocksJSON: syncedBlocksJSON,
            onOpenTagged: openSynced,
            onSyncedRemoved: onSyncedRemoved,
            onDeleteSynced: onDeleteSynced,
            revealRequest: workspace.revealRequest?.key == id.uuidString ? workspace.revealRequest : nil
        )
    }

    private var mentionContext: EditorMentionContext {
        var context = EditorMentionContext()
        context.pages = lists.filter { !$0.isEverythingList && !$0.isTagPage }.map {
            .init(id: $0.id.uuidString, title: $0.title, kind: $0.pageKind.rawValue)
        }
        context.tags = lists.filter(\.isTagPage).map { .init(id: $0.id.uuidString, title: $0.title) }
        context.tasks = openTasks.map {
            .init(id: $0.id.uuidString, title: $0.title, page: $0.list?.title ?? "")
        }
        return context
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
                context.tasks[id.uuidString] = .init(page: task.list?.title ?? "a page", pageId: task.list?.id.uuidString ?? "")
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
        // The first #tag of a name makes its tag page (#102).
        TagPages.ensurePages(for: json, in: modelContext)
        try? modelContext.save()
        if key == id.uuidString { onSaved?(json) }
        NotificationCenter.default.post(name: TagPages.documentSaved, object: nil)
    }

    /// "Open in …" on a synced block (#113): the page or task where it
    /// lives, with the caret on the block.
    private func openSynced(_ holderID: UUID, _ blockID: String?, _ isTask: Bool) {
        let holder = Self.holder(for: holderID.uuidString, in: modelContext)
        let path = blockID.flatMap { id in holder.flatMap { PageTags.path(ofBlock: id, in: $0.documentJSON) } }
        mentionActions.openLine(holderID, path, isTask)
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

/// Opens what a mention chip points to (#81): a page, a task, or a day on
/// Today or Upcoming. WorkspaceView provides it; elsewhere a chip does nothing.
struct EditorMentionActions {
    var open: (EditorMention) -> Void = { _ in }
    /// A tag page's line (#102): the page or task holding it, and where.
    var openLine: (_ holderID: UUID, _ path: [Int]?, _ isTask: Bool) -> Void = { _, _, _ in }
}

extension EnvironmentValues {
    @Entry var editorMentionActions = EditorMentionActions()
}

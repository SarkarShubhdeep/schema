//
//  ScratchpadPageView.swift
//  Schema
//
//  A scratchpad page: its header, then its document in the TipTap editor
//  (#77). The header stays put while the page scrolls under it.
//
//  A tag page (#102) is the same page, named #tag: what you write on it,
//  then every block tagged with it on other pages, as synced blocks you
//  can edit right here (#113, TagPages).
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ScratchpadPageView: View {
    let page: SchemaList
    var taskActions: BlockTaskActions?

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkspaceState.self) private var workspace
    /// Set by Rename in a menu; focuses the title with its text selected.
    @State private var titleFocus: BlockFocusRequest?
    @State private var editorFocus: EditorFocusRequest?
    /// On a tag page: its lines from other pages, and whether done ones hide.
    @State private var synced: TagPages.Synced?
    /// Delete everywhere… on a synced block, waiting for its confirmation.
    @State private var pendingDelete: PendingSyncedDelete?
    @State private var hidesDone = false
    @State private var groupsByPage = true

    var body: some View {
        VStack(spacing: 18) {
            header
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 28)
            editor
        }
        .background(hiddenShortcuts)
        .onAppear(perform: pageAppeared)
        .onChange(of: page.id) { _, _ in pageAppeared() }
        .onChange(of: hidesDone) { _, _ in gatherTagged() }
        .overlay {
            if let pending = pendingDelete {
                DeleteConfirmationDialog(
                    title: "Delete it everywhere?",
                    message: "It is deleted from \(pending.source) and leaves every tag page. This can\u{2019}t be undone.",
                    cta: "Delete everywhere",
                    onCancel: { pendingDelete = nil },
                    onConfirm: {
                        TagPages.deleteEverywhere(holderID: pending.holderID, blockID: pending.blockID, kind: pending.kind, in: modelContext)
                        pendingDelete = nil
                        gatherTagged()
                    }
                )
            }
        }
        .onChange(of: groupsByPage) { _, grouped in
            var ungrouped = SchemaPreferences.ungroupedTagPageIDs
            if grouped { ungrouped.remove(page.id) } else { ungrouped.insert(page.id) }
            SchemaPreferences.ungroupedTagPageIDs = ungrouped
            gatherTagged()
        }
        .onReceive(NotificationCenter.default.publisher(for: TagPages.documentSaved)) { _ in gatherTagged() }
        .onChange(of: workspace.pageRenameRequest) { _, _ in takeRenameRequest() }
    }

    private var editor: some View {
        let isTag = page.isTagPage
        let saved: ((String) -> Void)? = isTag ? { json in writeBack(json) } : nil
        let removed: (([(holderID: UUID, blockID: String, kind: String)]) -> Void)? = isTag ? { items in removeTag(items) } : nil
        let delete: ((UUID, String, String, String) -> Void)? = isTag
            ? { holderID, blockID, kind, source in pendingDelete = PendingSyncedDelete(holderID: holderID, blockID: blockID, kind: kind, source: source) }
            : nil
        return PageBodyEditor(
            holder: page,
            id: page.id,
            taskActions: taskActions,
            focusRequest: editorFocus,
            syncedBlocksJSON: isTag ? (synced?.json ?? "null") : nil,
            onSaved: saved,
            onSyncedRemoved: removed,
            onDeleteSynced: delete
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 6) {
                Text(page.isTagPage ? "Tags" : "Pages")
                Text("/").foregroundStyle(SchemaTheme.inkFaint)
                Text(page.isTagPage ? "#\(page.title)" : page.title).lineLimit(1)
                Spacer(minLength: 12)
                if page.isTagPage {
                    Button(hidesDone ? "Show done" : "Hide done") { hidesDone.toggle() }
                        .buttonStyle(.schema(.secondary))
                        .help(hidesDone ? "Show ticked lines from other pages" : "Hide ticked lines from other pages")
                } else {
                    Button {
                        QuickNoteController.shared.show()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Quick note")
                            SchemaKeyHint("⌃⌥N")
                        }
                    }
                    .buttonStyle(.schema(.secondary))
                    .help("Write a note from any app  ⌃⌥N")
                }
                pageMenu
            }
            .font(.satoshi(13, weight: .medium, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.inkMuted)

            VStack(alignment: .leading, spacing: 4) {
                Label(editedLabel, systemImage: page.pageKind.systemImage)
                    .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.inkMuted)
                if page.isTagPage {
                    // The # sits on the title's line; the name after it is what you edit.
                    HStack(alignment: .top, spacing: 2) {
                        Text("#")
                            .font(Font(PageTitleField.style.font as CTFont))
                            .kerning(PageTitleField.style.kern)
                            .foregroundStyle(SchemaTheme.inkFaint)
                            .frame(height: PageTitleField.style.lineHeight)
                            .fixedSize()
                            .accessibilityHidden(true)
                        title
                    }
                } else {
                    title
                }
            }
        }
        // Line up with the text column of the editor below.
        .padding(.leading, PageBodyEditor.gutterWidth)
    }

    /// The page title, editable in place (#42). Return or ↓ moves to the first line.
    private var title: some View {
        PageTitleField(
            title: page.title,
            pageID: page.id,
            focusRequest: titleFocus,
            onRename: { newTitle in
                if page.isTagPage {
                    // The tag's chips and "#name" in task titles follow (#102).
                    TagPages.rename(page, to: newTitle, in: modelContext)
                    gatherTagged()
                } else {
                    page.title = newTitle
                    try? modelContext.save()
                }
            },
            onDone: { editorFocus = EditorFocusRequest(position: .start) },
            onEditingChange: { workspace.isEditingListName = $0 }
        )
    }

    /// Page options: make tasks from every open to-do line at once, rename,
    /// copy or export as Markdown (#79), delete.
    private var pageMenu: some View {
        SchemaMenuButton("Page options") {
            SchemaMenuItem.header(page.isTagPage ? "#\(page.title)" : page.title)
            if let actions = taskActions {
                let open = PageDocument.openToDosWithoutTasks(in: page.documentJSON).count
                SchemaMenuItem.submenu(
                    open == 0 ? "No open to-dos without a task" : "Make tasks from \(open) open to-do\(open == 1 ? "" : "s")",
                    isDisabled: open == 0
                ) {
                    for target in actions.taskPages {
                        SchemaMenuItem.action(target.title) { makeTasksFromOpenToDos(in: target, actions: actions) }
                    }
                }
            }
            if page.isTagPage {
                SchemaMenuItem.divider
                SchemaMenuItem.action("Group by page", isChecked: groupsByPage) { groupsByPage.toggle() }
                SchemaMenuItem.action(hidesDone ? "Show done" : "Hide done") { hidesDone.toggle() }
                SchemaMenuItem.divider
            }
            SchemaMenuItem.action("Rename") { workspace.requestPageRename(page.id) }
            SchemaMenuItem.action("Copy as Markdown", shortcut: "\u{21E7}\u{2318}C", copyMarkdown)
            SchemaMenuItem.action("Export as Markdown\u{2026}", exportMarkdown)
            SchemaMenuItem.divider
            SchemaMenuItem.action(page.isTagPage ? "Delete tag\u{2026}" : "Delete page\u{2026}", isDestructive: true) { workspace.requestPageDelete(page.id) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.ink)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .fixedSize()
        .help("Page options")
    }

    /// ⇧⌘C copies the page as Markdown, even while the editor has focus.
    private var hiddenShortcuts: some View {
        Button("Copy as Markdown", action: copyMarkdown)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .hidden()
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    // MARK: Markdown

    private var markdown: String {
        PageMarkdown.markdown(fromJSON: page.documentJSON, title: page.title)
    }

    private func copyMarkdown() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.title = "Export as Markdown"
        panel.nameFieldStringValue = PageMarkdown.fileName(for: page.title)
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        let text = markdown
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try Data(text.utf8).write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func makeTasksFromOpenToDos(in target: SchemaList, actions: BlockTaskActions) {
        let result = PageDocument.linkingOpenToDos(in: page.documentJSON) { text in
            actions.makeTask(text, target)?.id
        }
        guard result.made > 0 else { return }
        page.setDocument(result.json)
        try? modelContext.save()
    }

    // MARK: Appearing and rename

    private func pageAppeared() {
        takeRenameRequest()
        groupsByPage = !SchemaPreferences.ungroupedTagPageIDs.contains(page.id)
        gatherTagged()
        // A new page opens with the caret on its first line.
        if titleFocus == nil, page.documentText.isEmpty, !page.hasDocument {
            editorFocus = EditorFocusRequest(position: .start)
        }
    }

    private func takeRenameRequest() {
        guard workspace.takePageRenameRequest(for: page.id) else { return }
        titleFocus = BlockFocusRequest(blockID: page.id, caret: .all)
    }

    private var editedLabel: String {
        if page.isTagPage {
            let open = synced?.openCount ?? 0
            let pages = synced?.pageCount ?? 0
            return "Tag page · \(open) open to-do\(open == 1 ? "" : "s") · synced from \(pages) page\(pages == 1 ? "" : "s")"
        }
        guard let edited = page.documentEditedAt, !page.documentText.isEmpty else { return "Scratchpad" }
        return "Scratchpad · edited \(edited.formatted(.relative(presentation: .named)))"
    }

    // MARK: Tag page (#102)

    /// The tag's synced blocks as they are now, gathered again after any
    /// save anywhere; the editor updates them in place.
    private func gatherTagged() {
        guard page.isTagPage else {
            synced = nil
            return
        }
        let next = TagPages.synced(for: page, hideDone: hidesDone, grouped: groupsByPage, in: modelContext)
        if next != synced { synced = next }
    }

    /// The tag page was saved: its synced blocks' edits go where they live.
    private func writeBack(_ json: String) {
        TagPages.writeBack(json, in: modelContext) { task in taskActions?.toggleTask(task) }
    }

    private func removeTag(_ items: [(holderID: UUID, blockID: String, kind: String)]) {
        TagPages.removeTag(page, from: items, in: modelContext)
        gatherTagged()
    }
}

/// Delete everywhere… on a synced block (#113), until it is confirmed.
private struct PendingSyncedDelete: Equatable {
    let holderID: UUID
    let blockID: String
    let kind: String
    let source: String
}

extension PageKind {
    var displayName: String {
        switch self {
        case .todo: "To-do list"
        case .scratchpad: "Scratchpad"
        case .tag: "Tag page"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "checklist"
        case .scratchpad: "doc.text"
        case .tag: "number"
        }
    }
}

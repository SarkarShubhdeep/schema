//
//  ScratchpadPageView.swift
//  Schema
//
//  A scratchpad page: its header, then its document in the TipTap editor
//  (#77). The header stays put while the page scrolls under it.
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

    var body: some View {
        VStack(spacing: 18) {
            header
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 28)
            PageBodyEditor(
                holder: page,
                id: page.id,
                taskActions: taskActions,
                focusRequest: editorFocus
            )
        }
        .background(hiddenShortcuts)
        .onAppear(perform: pageAppeared)
        .onChange(of: page.id) { _, _ in pageAppeared() }
        .onChange(of: workspace.pageRenameRequest) { _, _ in takeRenameRequest() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 6) {
                Text("Pages")
                Text("/").foregroundStyle(SchemaTheme.inkFaint)
                Text(page.title).lineLimit(1)
                Spacer(minLength: 12)
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
                pageMenu
            }
            .font(.satoshi(13, weight: .medium, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.inkMuted)

            VStack(alignment: .leading, spacing: 4) {
                Label(editedLabel, systemImage: PageKind.scratchpad.systemImage)
                    .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.inkMuted)
                title
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
                page.title = newTitle
                try? modelContext.save()
            },
            onDone: { editorFocus = EditorFocusRequest(position: .start) },
            onEditingChange: { workspace.isEditingListName = $0 }
        )
    }

    /// Page options: make tasks from every open to-do line at once, rename,
    /// copy or export as Markdown (#79), delete.
    private var pageMenu: some View {
        SchemaMenuButton("Page options") {
            SchemaMenuItem.header(page.title)
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
            SchemaMenuItem.action("Rename") { workspace.requestPageRename(page.id) }
            SchemaMenuItem.action("Copy as Markdown", shortcut: "\u{21E7}\u{2318}C", copyMarkdown)
            SchemaMenuItem.action("Export as Markdown\u{2026}", exportMarkdown)
            SchemaMenuItem.divider
            SchemaMenuItem.action("Delete page\u{2026}", isDestructive: true) { workspace.requestPageDelete(page.id) }
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
        guard let edited = page.documentEditedAt, !page.documentText.isEmpty else { return "Scratchpad" }
        return "Scratchpad · edited \(edited.formatted(.relative(presentation: .named)))"
    }
}

extension PageKind {
    var displayName: String {
        switch self {
        case .todo: "To-do list"
        case .scratchpad: "Scratchpad"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "checklist"
        case .scratchpad: "doc.text"
        }
    }
}

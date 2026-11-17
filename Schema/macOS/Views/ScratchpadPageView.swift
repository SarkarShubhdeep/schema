//
//  ScratchpadPageView.swift
//  Schema
//
//  A scratchpad page: its header, then the block editor (#38). Click below
//  the last line to keep writing. The / menu and markdown shortcuts come
//  in #39; until then, right-click a line to change its kind.
//

import SwiftData
import SwiftUI

struct ScratchpadPageView: View {
    let page: SchemaList
    var taskActions: BlockTaskActions?

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkspaceState.self) private var workspace
    @State private var editor: BlockEditor?
    /// Set by Rename in a menu; focuses the title with its text selected.
    @State private var titleFocus: BlockFocusRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let editor {
                    BlockListView(editor: editor, taskActions: taskActions)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 28)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            makeEditor()
            takeRenameRequest()
        }
        .onChange(of: page.id) { _, _ in makeEditor() }
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
        // Keep the gutter column of the blocks below aligned with the text.
        .padding(.leading, BlockListView.gutterWidth)
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
            onDone: { editor?.focusFirstLine() },
            onEditingChange: { workspace.isEditingListName = $0 }
        )
    }

    /// Page options: make tasks from every open to-do line at once, rename, delete.
    private var pageMenu: some View {
        Menu {
            if let editor, let actions = taskActions {
                let open = editor.openToDosWithoutTasks(actions: actions)
                Section(open.isEmpty ? "No open to-dos without a task" : "Make tasks from \(open.count) open to-do\(open.count == 1 ? "" : "s")") {
                    ForEach(actions.taskPages) { target in
                        Button("In \(target.title)") {
                            _ = editor.makeTasksFromOpenToDos(in: target, actions: actions)
                        }
                        .disabled(open.isEmpty)
                    }
                }
            }
            PageManageMenuItems(page: page)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.ink)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Page options")
        .accessibilityLabel("Page options")
    }

    // MARK: Rename

    private func takeRenameRequest() {
        guard workspace.takePageRenameRequest(for: page.id) else { return }
        titleFocus = BlockFocusRequest(blockID: page.id, caret: .all)
    }

    private var editedLabel: String {
        guard let latest = page.blocks.filter({ !$0.text.isEmpty }).map(\.updatedAt).max() else { return "Scratchpad" }
        let relative = latest.formatted(.relative(presentation: .named))
        return "Scratchpad · edited \(relative)"
    }

    private func makeEditor() {
        guard editor?.ownerID != page.id else { return }
        let editor = BlockEditor(owner: .page(page), context: modelContext)
        self.editor = editor
        // A new page opens with the caret on its first line.
        if page.blocks.isEmpty {
            editor.focusEnd()
        }
        #if DEBUG
        if DemoData.isEnabled, DemoData.opensSlashMenu,
           let quote = editor.blocks.first(where: { $0.kind == .quote }) {
            let line = editor.insertBlock(after: quote, kind: .text)
            editor.userTyped("/", in: line)
            editor.moveMenuSelection(by: 3)
            editor.focus(line, caret: .end)
        }
        if DemoData.isEnabled, DemoData.focusesOpenToDo,
           let line = editor.blocks.first(where: { $0.kind == .todo && $0.linkedTaskID == nil }) {
            editor.focus(line, caret: .end)
        }
        #endif
    }
}

/// The blocks, then empty space that adds a line when clicked.
struct BlockListView: View {
    static let gutterWidth: CGFloat = 32

    let editor: BlockEditor
    var taskActions: BlockTaskActions?
    /// Shown in place of the lines while there are none.
    var emptyPrompt: String?

    var body: some View {
        let blocks = editor.blocks
        // Lazy, so a long page only builds the lines on screen (#45). The
        // reader brings a line into view before it takes the caret, since an
        // off-screen line has no text view yet.
        ScrollViewReader { proxy in
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(blocks) { block in
                BlockRowView(
                    block: block,
                    editor: editor,
                    placeholder: placeholder(for: block, isOnly: blocks.count == 1),
                    taskActions: taskActions
                )
                // The / menu hangs over the lines below.
                .zIndex(editor.slashMenu?.blockID == block.id ? 1 : 0)
            }
            if blocks.isEmpty, let emptyPrompt {
                Text(emptyPrompt)
                    .font(.satoshi(15, relativeTo: .body))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .padding(.leading, Self.gutterWidth)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { editor.focusEnd() }
            }
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 160)
                .contentShape(Rectangle())
                .onTapGesture { editor.focusEnd() }
                .accessibilityLabel("Add a line")
                .accessibilityAddTraits(.isButton)
        }
        .onChange(of: editor.focusRequest?.token) { _, _ in
            guard let id = editor.focusRequest?.blockID else { return }
            proxy.scrollTo(id)
        }
        }
    }

    private func placeholder(for block: SchemaBlock, isOnly: Bool) -> String {
        switch block.kind {
        case .heading: "Heading"
        case .todo: "To-do"
        case .bullet, .quote: ""
        case .text, .divider: isOnly ? "Start writing, or type / for blocks" : "Type / for blocks"
        }
    }
}

extension BlockEditor {
    var ownerID: UUID {
        switch owner {
        case .page(let page): page.id
        case .task(let task): task.id
        }
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

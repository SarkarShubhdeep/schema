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

    @Environment(\.modelContext) private var modelContext
    @State private var editor: BlockEditor?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let editor {
                    BlockListView(editor: editor)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 28)
        }
        .scrollContentBackground(.hidden)
        .onAppear(perform: makeEditor)
        .onChange(of: page.id) { _, _ in makeEditor() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 6) {
                Text("Pages")
                Text("/").foregroundStyle(SchemaTheme.inkFaint)
                Text(page.title).lineLimit(1)
            }
            .font(.satoshi(13, weight: .medium, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.inkMuted)

            VStack(alignment: .leading, spacing: 4) {
                Label(editedLabel, systemImage: PageKind.scratchpad.systemImage)
                    .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.inkMuted)
                Text(page.title)
                    .font(.spaceGrotesk(44, weight: .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        // Keep the gutter column of the blocks below aligned with the text.
        .padding(.leading, BlockListView.gutterWidth)
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
        #endif
    }
}

/// The blocks, then empty space that adds a line when clicked.
struct BlockListView: View {
    static let gutterWidth: CGFloat = 32

    let editor: BlockEditor

    var body: some View {
        let blocks = editor.blocks
        VStack(alignment: .leading, spacing: 2) {
            ForEach(blocks) { block in
                BlockRowView(
                    block: block,
                    editor: editor,
                    placeholder: placeholder(for: block, isOnly: blocks.count == 1)
                )
                // The / menu hangs over the lines below.
                .zIndex(editor.slashMenu?.blockID == block.id ? 1 : 0)
            }
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 160)
                .contentShape(Rectangle())
                .onTapGesture { editor.focusEnd() }
                .accessibilityLabel("Add a line")
                .accessibilityAddTraits(.isButton)
        }
        // The gutter hangs left of the text column, as on the canvas.
        .padding(.leading, 0)
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

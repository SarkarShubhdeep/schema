//
//  BlockListView.swift
//  Schema
//
//  The v0.5 block editor's list of lines. Pages use TipTap since #77; this
//  goes when the old editor is removed (#82).
//

import SwiftUI

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

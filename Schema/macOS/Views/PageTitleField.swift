//
//  PageTitleField.swift
//  Schema
//
//  A page's large title, editable in place like the text below it: click
//  and type. It is the same text view as the blocks, so letter spacing and
//  line height don't change while editing. Return or clicking away saves;
//  Esc puts the old name back.
//

import AppKit
import SwiftUI

struct PageTitleField: View {
    let title: String
    let pageID: UUID
    /// Rename from a menu: focus the title with all of it selected.
    let focusRequest: BlockFocusRequest?
    let onRename: (String) -> Void
    /// After Return, or ↓ on the last line: e.g. move to the first block.
    var onDone: (() -> Void)?
    var onEditingChange: (Bool) -> Void = { _ in }

    @State private var draft = ""

    static let style = BlockTextStyle(
        font: .schemaDisplay(44, weight: .semibold),
        color: NSColor(SchemaTheme.ink),
        lineHeight: 52,
        kern: -1.2
    )

    var body: some View {
        BlockTextView(
            text: draft,
            style: Self.style,
            placeholder: "Untitled",
            focusRequest: focusRequest,
            blockID: pageID,
            onTextChange: { draft = $0 },
            onReturn: { _ in finish() },
            onBackspaceAtStart: {},
            onArrowOut: { forward in if forward { finish() } },
            onFocusChange: { focused in
                onEditingChange(focused)
                if !focused { commit() }
            },
            onEscape: {
                draft = title
                resign()
            }
        )
        .onAppear { draft = title }
        .onChange(of: title) { _, newTitle in draft = newTitle }
        .onChange(of: pageID) { _, _ in draft = title }
        .help("Click to rename")
        .accessibilityLabel("Page name")
        .accessibilityAddTraits(.isHeader)
    }

    private func finish() {
        commit()
        if let onDone { onDone() } else { resign() }
    }

    private func commit() {
        let cleaned = draft
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A blank name, or "Everything", keeps the old one.
        guard !cleaned.isEmpty, cleaned != SchemaList.everythingTitle else {
            draft = title
            return
        }
        if cleaned != title { onRename(cleaned) }
        draft = cleaned
    }

    private func resign() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

//
//  ListWritingView.swift
//  Schema
//
//  Writing above a to-do list's tasks (#123), in the same editor as notes.
//  Hidden while the page has none: Add writing in the ⋯ menu (⌥⌘W) opens it.
//

import SwiftUI

struct ListWritingView: View {
    @Environment(WorkspaceState.self) private var workspace

    let page: SchemaList
    let taskActions: BlockTaskActions

    @State private var isWriting = false
    @State private var focus: EditorFocusRequest?

    private var hasWriting: Bool {
        !page.documentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if hasWriting || isWriting {
                PageBodyEditor(
                    holder: page,
                    id: page.id,
                    taskActions: taskActions,
                    focusRequest: focus,
                    isInline: true
                )
                // The text lines up with the title; the gutter for block
                // handles sits to its left.
                .padding(.leading, -PageBodyEditor.gutterWidth)
            }
        }
        .onChange(of: workspace.listWritingRequest) { _, request in
            if request?.pageID == page.id { startWriting() }
        }
    }

    private func startWriting() {
        isWriting = true
        focus = EditorFocusRequest(position: .end)
    }
}

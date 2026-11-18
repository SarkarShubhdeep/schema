//
//  EditorFeelCheckView.swift
//  Schema
//
//  Debug only (#76): the current block editor and TipTap side by side on the
//  same page, to compare fonts, caret, typing, scrolling and shortcuts before
//  any data moves. TipTap gets a copy of the page; its edits are not saved.
//

#if DEBUG
import SwiftUI

struct EditorFeelCheckView<Current: View>: View {
    let page: SchemaList
    @ViewBuilder var current: Current

    @State private var documentJSON = ""

    var body: some View {
        HStack(spacing: 0) {
            column("Current editor") { current }
            Rectangle().fill(SchemaTheme.line).frame(width: 1)
            column("TipTap (not saved)") {
                TipTapEditorView(documentJSON: documentJSON)
                    .padding(.horizontal, 32 + BlockListView.gutterWidth)
                    .padding(.top, 12)
            }
        }
        .onAppear { documentJSON = TipTapDocument.json(TipTapDocument.document(from: page.blocks)) }
        .onChange(of: page.id) { _, _ in
            documentJSON = TipTapDocument.json(TipTapDocument.document(from: page.blocks))
        }
    }

    private func column<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.schemaLabel)
                .textCase(.uppercase)
                .tracking(0.9)
                .foregroundStyle(SchemaTheme.inkMuted)
                .padding(.horizontal, 32)
                .padding(.top, 14)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif

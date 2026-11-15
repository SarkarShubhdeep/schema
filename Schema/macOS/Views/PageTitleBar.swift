//
//  PageTitleBar.swift
//  Schema
//
//  Title of what the main column shows: a page, Everything, Today or
//  Upcoming, with its open-task count. Double-click a page title to rename
//  it. Navigation lives in the sidebar.
//

import SwiftUI

struct PageTitleBar: View {
    let title: String
    let count: Int
    /// The page to rename on double-click; `nil` for Everything and smart views.
    let renamableList: SchemaList?
    let onRename: (SchemaList, String) -> Void
    @Binding var isEditingListName: Bool

    @State private var isEditing = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isEditing, let renamableList {
                TextField("Page name", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .font(.spaceGrotesk(28, weight: .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(SchemaTheme.ink)
                    .focused($isTitleFocused)
                    .onSubmit { commit(renamableList) }
                    .onKeyPress(.escape) {
                        endEditing()
                        return .handled
                    }
            } else {
                Text(title)
                    .font(.spaceGrotesk(28, weight: .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) { beginEditing() }
                    .help(renamableList == nil ? "" : "Double-click to rename")
                    .accessibilityAddTraits(.isHeader)
            }

            if count > 0, !isEditing {
                SchemaBadge(count: count)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(SchemaTheme.canvas)
        .onChange(of: renamableList?.id) { _, _ in
            if isEditing { endEditing() }
        }
    }

    private func beginEditing() {
        guard let renamableList else { return }
        editedTitle = renamableList.title
        isEditing = true
        isEditingListName = true
        isTitleFocused = true
    }

    private func commit(_ list: SchemaList) {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != list.title {
            onRename(list, trimmed)
        }
        endEditing()
    }

    private func endEditing() {
        isEditing = false
        isTitleFocused = false
        isEditingListName = false
    }
}

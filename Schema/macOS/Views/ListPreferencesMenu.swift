//
//  ListPreferencesMenu.swift
//  Schema
//

import SwiftUI

struct ListPreferencesMenu: View {
    @Environment(WorkspaceState.self) private var workspace
    @Bindable var listViewModel: ListViewModel
    let requiresManualSort: Bool
    /// The page shown, for Rename and Delete; nil for views (#42).
    var page: SchemaList?

    var body: some View {
        Menu {
            Menu("Sort") {
                ForEach(TaskSortOption.allCases) { option in
                    Button {
                        withAnimation(SchemaMotion.smooth) {
                            listViewModel.sortOption = option
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            if listViewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(requiresManualSort && option != .manual)
                }
            }

            Menu("Filter") {
                ForEach(TaskFilterOption.allCases) { option in
                    Button {
                        withAnimation(SchemaMotion.smooth) {
                            listViewModel.filterOption = option
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            if listViewModel.filterOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if let page {
                PageManageMenuItems(page: page)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(SchemaTheme.surface))
                .overlay(Circle().strokeBorder(SchemaTheme.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Page options")
        .accessibilityLabel("Page options")
    }
}

/// Rename and Delete for a page; in the page menus and the sidebar (#42).
struct PageManageMenuItems: View {
    @Environment(WorkspaceState.self) private var workspace
    let page: SchemaList

    var body: some View {
        Divider()
        Button("Rename") { workspace.requestPageRename(page.id) }
        Button("Delete page\u{2026}", role: .destructive) { workspace.requestPageDelete(page.id) }
    }
}

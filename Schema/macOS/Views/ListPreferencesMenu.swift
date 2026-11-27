//
//  ListPreferencesMenu.swift
//  Schema
//
//  Page options (⋯) on to-do lists and views: Sort, Filter, and for a page
//  Rename and Delete. A Schema menu (#83).
//

import SwiftUI

struct ListPreferencesMenu: View {
    @Environment(WorkspaceState.self) private var workspace
    @Bindable var listViewModel: ListViewModel
    let requiresManualSort: Bool
    /// The page shown, for Rename and Delete; nil for views (#42).
    var page: SchemaList?

    var body: some View {
        SchemaMenuButton("Page options") {
            if let page { SchemaMenuItem.header(page.title) }
            SchemaMenuItem.submenu("Sort") {
                for option in TaskSortOption.allCases {
                    SchemaMenuItem.action(
                        option.label,
                        isChecked: listViewModel.sortOption == option,
                        isDisabled: requiresManualSort && option != .manual
                    ) {
                        withAnimation(SchemaMotion.smooth) { listViewModel.sortOption = option }
                    }
                }
            }
            SchemaMenuItem.submenu("Filter") {
                for option in TaskFilterOption.allCases {
                    SchemaMenuItem.action(option.label, isChecked: listViewModel.filterOption == option) {
                        withAnimation(SchemaMotion.smooth) { listViewModel.filterOption = option }
                    }
                }
            }
            if let page {
                if page.acceptsTasks {
                    SchemaMenuItem.divider
                    SchemaMenuItem.action("Add writing", shortcut: "⌥⌘W") { workspace.requestListWriting(page.id) }
                }
                PageManageMenu.items(for: page, workspace: workspace)
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
        .fixedSize()
        .help("Page options")
    }
}

/// Rename and Delete for a page; in the page menus and the sidebar (#42).
enum PageManageMenu {
    @MainActor
    @SchemaMenuBuilder
    static func items(for page: SchemaList, workspace: WorkspaceState) -> [SchemaMenuItem] {
        SchemaMenuItem.divider
        SchemaMenuItem.action("Rename") { workspace.requestPageRename(page.id) }
        SchemaMenuItem.divider
        SchemaMenuItem.action("Delete page\u{2026}", isDestructive: true) { workspace.requestPageDelete(page.id) }
    }
}

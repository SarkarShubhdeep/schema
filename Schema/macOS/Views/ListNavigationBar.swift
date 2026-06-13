//
//  ListNavigationBar.swift
//  Schema
//

import SwiftUI

struct ListNavigationBar: View {
    let lists: [SchemaList]
    let selectedListID: UUID?
    let onSelect: (SchemaList) -> Void
    let onCreateList: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            ForEach(lists) { list in
                Button {
                    onSelect(list)
                } label: {
                    Text(list.title)
                        .font(.system(size: 22, weight: selectedListID == list.id ? .semibold : .regular))
                        .foregroundStyle(selectedListID == list.id ? SchemaTheme.accent : SchemaTheme.tabInactive)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }

            Button(action: onCreateList) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)
            .help("New List (⌘N)")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(SchemaTheme.surface)
    }
}

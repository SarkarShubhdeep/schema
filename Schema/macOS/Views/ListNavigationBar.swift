//
//  ListNavigationBar.swift
//  Schema
//

import SwiftUI

struct ListNavigationBar: View {
    let lists: [SchemaList]
    let selectedListID: UUID?
    let taskCount: (SchemaList) -> Int
    let onSelect: (SchemaList) -> Void
    let onRename: (SchemaList, String) -> Void
    @Binding var isEditingListName: Bool

    @State private var editingListID: UUID?
    @State private var editedTitle = ""
    @State private var lastTapDate: Date?
    @State private var lastTappedListID: UUID?
    @FocusState private var isTitleFocused: Bool

    private let doubleTapInterval: TimeInterval = 0.35

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(lists) { list in
                        listTab(for: list)
                            .id(list.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
            }
            .background(SchemaTheme.background)
            .animation(SchemaMotion.fast, value: selectedListID)
            .onAppear {
                scrollToSelectedList(using: proxy, animated: false)
            }
            .onChange(of: selectedListID) { _, _ in
                scrollToSelectedList(using: proxy, animated: true)
            }
        }
    }

    @ViewBuilder
    private func listTab(for list: SchemaList) -> some View {
        HStack(spacing: 10) {
            if editingListID == list.id {
                titleField(for: list)
            } else {
                titleLabel(for: list)
            }

            taskCountBadge(for: list)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTabTap(for: list)
        }
    }

    private func titleLabel(for list: SchemaList) -> some View {
        Text(list.title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(SchemaTheme.tabColor(
                for: list,
                isSelected: selectedListID == list.id
            ))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func titleField(for list: SchemaList) -> some View {
        TextField("List name", text: $editedTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(SchemaTheme.tabColor(
                for: list,
                isSelected: selectedListID == list.id
            ))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .focused($isTitleFocused)
            .onSubmit {
                commitEditing(for: list)
            }
            .onKeyPress(.escape) {
                cancelEditing()
                return .handled
            }
    }

    @ViewBuilder
    private func taskCountBadge(for list: SchemaList) -> some View {
        let count = taskCount(list)
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SchemaTheme.mutedText)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(SchemaTheme.countBadgeBackground)
                )
        }
    }

    private func handleTabTap(for list: SchemaList) {
        guard editingListID == nil else { return }

        let now = Date()
        if let lastTapDate,
           lastTappedListID == list.id,
           now.timeIntervalSince(lastTapDate) <= doubleTapInterval,
           !list.isEverythingList {
            beginEditing(list)
            self.lastTapDate = nil
            self.lastTappedListID = nil
            return
        }

        lastTapDate = now
        lastTappedListID = list.id
        onSelect(list)
    }

    private func beginEditing(_ list: SchemaList) {
        editedTitle = list.title
        editingListID = list.id
        isEditingListName = true
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    private func commitEditing(for list: SchemaList) {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != list.title {
            onRename(list, trimmed)
        }
        editingListID = nil
        isTitleFocused = false
        isEditingListName = false
    }

    private func cancelEditing() {
        editingListID = nil
        isTitleFocused = false
        isEditingListName = false
    }

    private func scrollToSelectedList(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedListID else { return }

        if animated {
            withAnimation(SchemaMotion.fast) {
                proxy.scrollTo(selectedListID, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedListID, anchor: .center)
        }
    }
}

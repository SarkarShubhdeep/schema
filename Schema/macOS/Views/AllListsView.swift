//
//  AllListsView.swift
//  Schema
//

import SwiftUI

struct AllListsView: View {
    let lists: [SchemaList]
    @Bindable var listViewModel: ListViewModel
    let onSelectList: (SchemaList) -> Void

    @State private var listToRename: SchemaList?
    @State private var renameTitle = ""

    private enum CardMetrics {
        static let minHeight: CGFloat = 140
        static let cornerRadius: CGFloat = 16
        static let padding: CGFloat = 18
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 20)
    ]

    private var gridLists: [SchemaList] {
        lists.filter { !$0.isEverythingList }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                newListCard

                ForEach(gridLists) { list in
                    listCard(for: list)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(SchemaTheme.canvas)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $listViewModel.showNewListSheet) {
            NewListSheet(
                title: $listViewModel.newListTitle,
                onCreate: {
                    listViewModel.createList(title: listViewModel.newListTitle, existingLists: lists)
                },
                onCancel: {
                    listViewModel.newListTitle = ""
                    listViewModel.showNewListSheet = false
                }
            )
        }
        .sheet(isPresented: renameSheetPresented) {
            if let list = listToRename {
                RenameListSheet(
                    title: $renameTitle,
                    onSave: {
                        listViewModel.updateListTitle(list, title: renameTitle)
                        listToRename = nil
                    },
                    onCancel: {
                        listToRename = nil
                    }
                )
            }
        }
    }

    private var renameSheetPresented: Binding<Bool> {
        Binding(
            get: { listToRename != nil },
            set: { isPresented in
                if !isPresented {
                    listToRename = nil
                }
            }
        )
    }

    private var newListCard: some View {
        Button {
            listViewModel.showNewListSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                Text("+ New list")
                    .font(.satoshi(15, weight: .medium))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: CardMetrics.minHeight, alignment: .leading)
            .padding(CardMetrics.padding)
            .background(
                RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
                    .fill(SchemaTheme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(
                        SchemaTheme.inkMuted.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
    }

    private func listCard(for list: SchemaList) -> some View {
        Button {
            onSelectList(list)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(list.title)
                    .font(.spaceGrotesk(17, weight: .semibold))
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Text(taskCountLabel(for: list))
                    .font(.spaceGrotesk(13, weight: .medium).monospacedDigit())
                    .foregroundStyle(SchemaTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, minHeight: CardMetrics.minHeight, alignment: .leading)
            .padding(CardMetrics.padding)
            .background(
                RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
                    .fill(SchemaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
                    .stroke(SchemaTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") {
                listToRename = list
                renameTitle = list.title
            }

            Divider()

            Button("Delete List", role: .destructive) {
                listViewModel.deleteList(list, from: lists)
            }
        }
    }

    private func taskCountLabel(for list: SchemaList) -> String {
        let count = list.incompleteTaskCount
        return count == 1 ? "1 task" : "\(count) tasks"
    }
}

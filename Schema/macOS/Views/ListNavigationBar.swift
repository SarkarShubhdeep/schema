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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(lists) { list in
                        Button {
                            onSelect(list)
                        } label: {
                            HStack(spacing: 10) {
                                Text(list.title)
                                    .font(.system(
                                        size: 28,
                                        weight: .bold
                                    ))
                                    .foregroundStyle(SchemaTheme.tabColor(
                                        for: list,
                                        isSelected: selectedListID == list.id
                                    ))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                taskCountBadge(for: list)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .id(list.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
            }
            .background(SchemaTheme.background)
            .animation(SchemaMotion.standard, value: selectedListID)
            .onAppear {
                scrollToSelectedList(using: proxy, animated: false)
            }
            .onChange(of: selectedListID) { _, _ in
                scrollToSelectedList(using: proxy, animated: true)
            }
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

    private func scrollToSelectedList(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedListID else { return }

        if animated {
            withAnimation(SchemaMotion.smooth) {
                proxy.scrollTo(selectedListID, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedListID, anchor: .center)
        }
    }
}

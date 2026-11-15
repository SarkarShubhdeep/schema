//
//  SidebarNavigation.swift
//  Schema
//
//  The sidebar's Views (Today, Upcoming, Everything) and Pages, as full rows
//  when the sidebar is open and as round icons on the collapsed rail.
//  The active item is a dark pill.
//

import SwiftUI

struct SidebarNavigation: View {
    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let isRail: Bool

    private var pages: [SchemaList] { listViewModel.pages(from: lists) }

    var body: some View {
        if isRail {
            railItems
        } else {
            rows
        }
    }

    // MARK: Open sidebar

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            SchemaSectionLabel("Views")
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ForEach(SmartView.allCases) { view in
                SidebarRow(
                    title: view.title,
                    systemImage: view.systemImage,
                    isActive: listViewModel.smartView == view,
                    trailing: .count(count(for: view))
                ) {
                    listViewModel.selectSmartView(view, from: lists)
                }
            }

            SidebarRow(
                title: SchemaList.everythingTitle,
                systemImage: "tray.full",
                isActive: isEverythingActive,
                trailing: .keys("/")
            ) {
                listViewModel.selectEverythingList(from: lists)
            }

            HStack {
                SchemaSectionLabel("Pages")
                Spacer(minLength: 8)
                SchemaIconButton(systemImage: "plus", label: "New page", shortcut: "⌘N", size: 24) {
                    listViewModel.showNewListSheet = true
                }
            }
            .padding(.leading, 12)
            .padding(.top, 14)
            .padding(.bottom, 2)

            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                SidebarRow(
                    title: page.title,
                    systemImage: "checklist",
                    isActive: isActive(page),
                    trailing: index < 9 ? .keys("⌘\(index + 1)") : .none
                ) {
                    listViewModel.selectList(page)
                }
                .help("To-do list")
            }

            SidebarRow(title: "New page", systemImage: "plus", isActive: false, isSubtle: true, trailing: .keys("⌘N")) {
                listViewModel.showNewListSheet = true
            }
            .padding(.top, 6)
        }
    }

    // MARK: Rail

    private var railItems: some View {
        VStack(spacing: 4) {
            ForEach(SmartView.allCases) { view in
                RailItem(label: view.title, isActive: listViewModel.smartView == view) {
                    Image(systemName: view.systemImage)
                } action: {
                    listViewModel.selectSmartView(view, from: lists)
                }
            }
            RailItem(label: "\(SchemaList.everythingTitle)  /", isActive: isEverythingActive) {
                Image(systemName: "tray.full")
            } action: {
                listViewModel.selectEverythingList(from: lists)
            }

            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 28, height: 1)
                .padding(.vertical, 6)

            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                RailItem(
                    label: index < 9 ? "\(page.title) (to-do list)  ⌘\(index + 1)" : "\(page.title) (to-do list)",
                    isActive: isActive(page)
                ) {
                    Text(page.title.prefix(1).uppercased())
                        .font(.spaceGrotesk(14, weight: .semibold, relativeTo: .body))
                } action: {
                    listViewModel.selectList(page)
                }
            }

            RailItem(label: "New page  ⌘N", isActive: false) {
                Image(systemName: "plus")
            } action: {
                listViewModel.showNewListSheet = true
            }
        }
    }

    // MARK: State

    private var isEverythingActive: Bool {
        listViewModel.smartView == nil && listViewModel.selectedList(from: lists)?.isEverythingList == true
    }

    private func isActive(_ page: SchemaList) -> Bool {
        listViewModel.smartView == nil && listViewModel.selectedListID == page.id
    }

    private func count(for view: SmartView) -> Int {
        let now = Date.now
        return allTasks.count { !$0.isCompleted && view.includes($0, now: now) }
    }
}

// MARK: - Row

private enum SidebarRowTrailing {
    case count(Int)
    case keys(String)
    case none
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    var isSubtle = false
    let trailing: SidebarRowTrailing
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(title)
                    .font(.schemaControl)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                trailingView
            }
            .foregroundStyle(foreground)
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(height: 34)
            .background(Capsule(style: .continuous).fill(background))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .count(let count):
            if count > 0 {
                Text("\(count)")
                    .font(.schemaMeta)
                    .opacity(isActive ? 0.75 : 1)
            }
        case .keys(let keys):
            Text(keys)
                .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isActive ? SchemaTheme.canvas.opacity(0.35) : SchemaTheme.line, lineWidth: 1)
                )
                .opacity(isActive ? 0.75 : 1)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }

    private var foreground: Color {
        if isActive { return SchemaTheme.canvas }
        if isSubtle { return isHovered ? SchemaTheme.ink : SchemaTheme.inkFaint }
        return isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted
    }

    private var background: Color {
        if isActive { return SchemaTheme.ink }
        return isHovered ? SchemaTheme.surfaceHover : .clear
    }
}

// MARK: - Rail item

private struct RailItem<Icon: View>: View {
    let label: String
    let isActive: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            icon()
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? SchemaTheme.canvas : (isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted))
                .frame(width: 40, height: 40)
                .background(Circle().fill(isActive ? SchemaTheme.ink : (isHovered ? SchemaTheme.surfaceHover : .clear)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

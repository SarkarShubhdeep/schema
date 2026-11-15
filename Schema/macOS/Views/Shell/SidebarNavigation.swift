//
//  SidebarNavigation.swift
//  Schema
//
//  The sidebar's Views (Today, Upcoming, Everything) and Pages. The same rows
//  serve the open sidebar and the collapsed rail: as the sidebar narrows,
//  each pill tightens into a circle around its icon and the label slides out
//  of view, so collapsing reads as one motion rather than a swap.
//

import SwiftUI

struct SidebarNavigation: View {
    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let isCollapsed: Bool

    private var pages: [SchemaList] { listViewModel.pages(from: lists) }

    var body: some View {
        VStack(alignment: .leading, spacing: isCollapsed ? 4 : 2) {
            sectionHeader("Views")

            ForEach(SmartView.allCases) { view in
                SidebarRow(
                    title: view.title,
                    isActive: listViewModel.smartView == view,
                    isCollapsed: isCollapsed,
                    trailing: .count(count(for: view)),
                    tooltip: view.title
                ) {
                    Image(systemName: view.systemImage)
                } action: {
                    listViewModel.selectSmartView(view, from: lists)
                }
            }

            SidebarRow(
                title: SchemaList.everythingTitle,
                isActive: isEverythingActive,
                isCollapsed: isCollapsed,
                trailing: .keys("/"),
                tooltip: "\(SchemaList.everythingTitle)  /"
            ) {
                Image(systemName: "tray.full")
            } action: {
                listViewModel.selectEverythingList(from: lists)
            }

            sectionHeader("Pages", showsNewPage: true)

            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                let shortcut = index < 9 ? "⌘\(index + 1)" : nil
                SidebarRow(
                    title: page.title,
                    isActive: isActive(page),
                    isCollapsed: isCollapsed,
                    trailing: shortcut.map { .keys($0) } ?? .none,
                    tooltip: isCollapsed
                        ? "\(page.title) (to-do list)" + (shortcut.map { "  \($0)" } ?? "")
                        : "To-do list"
                ) {
                    ZStack {
                        if isCollapsed {
                            Text(page.title.prefix(1).uppercased())
                                .font(.spaceGrotesk(14, weight: .semibold, relativeTo: .body))
                                .transition(.opacity)
                        } else {
                            Image(systemName: "checklist")
                                .transition(.opacity)
                        }
                    }
                } action: {
                    listViewModel.selectList(page)
                }
            }

            SidebarRow(
                title: "New page",
                isActive: false,
                isCollapsed: isCollapsed,
                isSubtle: true,
                trailing: .keys("⌘N"),
                tooltip: "New page  ⌘N"
            ) {
                Image(systemName: "plus")
            } action: {
                listViewModel.showNewListSheet = true
            }
            .padding(.top, isCollapsed ? 0 : 6)
        }
    }

    /// Open: an uppercase label. Collapsed: a short divider in the same place.
    @ViewBuilder
    private func sectionHeader(_ title: String, showsNewPage: Bool = false) -> some View {
        ZStack(alignment: .leading) {
            if isCollapsed {
                Rectangle()
                    .fill(SchemaTheme.line)
                    .frame(width: 28, height: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .transition(.opacity)
            } else {
                HStack {
                    SchemaSectionLabel(title)
                        .fixedSize()
                    Spacer(minLength: 8)
                    if showsNewPage {
                        SchemaIconButton(systemImage: "plus", label: "New page", shortcut: "⌘N", size: 24) {
                            listViewModel.showNewListSheet = true
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.top, showsNewPage ? 14 : 12)
                .padding(.bottom, showsNewPage ? 2 : 4)
                .transition(.opacity)
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

/// One navigation item. Open: a 34pt pill with icon, label and trailing hint.
/// Collapsed: the same pill narrowed to a 40pt circle around the icon. The
/// icon keeps its horizontal position, so it stays put while the sidebar
/// changes width.
private struct SidebarRow<Icon: View>: View {
    let title: String
    let isActive: Bool
    let isCollapsed: Bool
    var isSubtle = false
    let trailing: SidebarRowTrailing
    let tooltip: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()
                    .font(.system(size: isCollapsed ? 15 : 12, weight: .medium))
                    .frame(width: 16, height: 16)

                if !isCollapsed {
                    Text(title)
                        .font(.schemaControl)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                    Spacer(minLength: 6)
                    trailingView
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(foreground)
            .padding(.leading, isCollapsed ? 12 : 14)
            .padding(.trailing, isCollapsed ? 0 : 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: isCollapsed ? 40 : 34)
            .background(Capsule(style: .continuous).fill(background))
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help(tooltip)
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

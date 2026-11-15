//
//  SidebarNavigation.swift
//  Schema
//
//  The sidebar's Views (Today, Upcoming, Everything) and Pages. The same rows
//  serve the open sidebar and the collapsed rail (see SidebarRow).
//

import SwiftUI

struct SidebarNavigation: View {
    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let isCollapsed: Bool

    private var pages: [SchemaList] { listViewModel.pages(from: lists) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, showsNewPage: Bool = false) -> some View {
        if showsNewPage {
            SidebarSectionHeader(title: title, isCollapsed: isCollapsed) {
                SchemaIconButton(systemImage: "plus", label: "New page", shortcut: "⌘N", size: 24) {
                    listViewModel.showNewListSheet = true
                }
            }
        } else {
            SidebarSectionHeader(title: title, isCollapsed: isCollapsed)
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

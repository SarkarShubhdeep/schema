//
//  SidebarNavigation.swift
//  Schema
//
//  The sidebar's Views (Today, Upcoming, Everything) and Pages. The same rows
//  serve the open sidebar and the collapsed rail (see SidebarRow).
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarNavigation: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let isCollapsed: Bool

    private var pages: [SchemaList] { listViewModel.pages(from: lists) }

    /// The page being dragged to a new place (#42).
    @State private var draggingPageID: UUID?

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
                        ? "\(page.title) (\(page.pageKind.displayName.lowercased()))" + (shortcut.map { "  \($0)" } ?? "")
                        : page.pageKind.displayName
                ) {
                    ZStack {
                        if isCollapsed {
                            Text(page.title.prefix(1).uppercased())
                                .font(.spaceGrotesk(14, weight: .semibold, relativeTo: .body))
                                .transition(.opacity)
                        } else {
                            Image(systemName: page.pageKind.systemImage)
                                .transition(.opacity)
                        }
                    }
                } action: {
                    listViewModel.selectList(page)
                }
                .opacity(draggingPageID == page.id ? 0.4 : 1)
                .contextMenu {
                    Button("Rename") {
                        listViewModel.selectList(page)
                        workspace.requestPageRename(page.id)
                    }
                    Button("Delete page\u{2026}", role: .destructive) {
                        workspace.requestPageDelete(page.id)
                    }
                }
                // Drag a page onto another to take its place; the list
                // reorders as the drag passes over rows.
                .onDrag {
                    draggingPageID = page.id
                    return NSItemProvider(object: page.id.uuidString as NSString)
                }
                .onDrop(of: [.plainText], delegate: PageDropDelegate(
                    targetID: page.id,
                    draggingID: $draggingPageID,
                    move: { moving, target in
                        withAnimation(SchemaMotion.smooth) {
                            _ = listViewModel.movePage(moving, to: target, in: lists)
                        }
                    }
                ))
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
                listViewModel.openNewPage()
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, showsNewPage: Bool = false) -> some View {
        if showsNewPage {
            SidebarSectionHeader(title: title, isCollapsed: isCollapsed) {
                SchemaIconButton(systemImage: "plus", label: "New page", shortcut: "⌘N", size: 24) {
                    listViewModel.openNewPage()
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

/// Reorders pages live while one is dragged over the others (#42).
private struct PageDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    let move: (_ moving: UUID, _ target: UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        move(draggingID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: draggingID == nil ? .forbidden : .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

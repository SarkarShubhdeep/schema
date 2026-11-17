//
//  SidebarNavigation.swift
//  Schema
//
//  The sidebar's Views (Today, Upcoming, Everything) and Pages. The same rows
//  serve the open sidebar and the collapsed rail (see SidebarRow).
//

import SwiftUI

struct SidebarNavigation: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let allTasks: [SchemaTask]
    let listViewModel: ListViewModel
    let isCollapsed: Bool

    private var pages: [SchemaList] { listViewModel.pages(from: lists) }

    /// The page being dragged to a new place (#42). Nothing is saved until
    /// the drag ends: while it moves, the row follows the pointer and the
    /// rows it passes slide out of its way.
    @State private var drag: PageDrag?

    /// Distance between two page rows (row height plus the stack spacing).
    private static let rowStep = SidebarMetrics.rowHeight + 2

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
                .contextMenu {
                    Button("Rename") {
                        listViewModel.selectList(page)
                        workspace.requestPageRename(page.id)
                    }
                    Button("Delete page\u{2026}", role: .destructive) {
                        workspace.requestPageDelete(page.id)
                    }
                }
                .background {
                    if drag?.id == page.id {
                        Capsule(style: .continuous)
                            .fill(SchemaTheme.surface)
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                            .transition(.opacity)
                    }
                }
                // Rows the drag passes over slide one step up or down.
                .offset(y: shift(forRowAt: index, id: page.id))
                .animation(SchemaMotion.smooth, value: shift(forRowAt: index, id: page.id))
                // The dragged row tracks the pointer exactly, unanimated.
                .offset(y: drag?.id == page.id ? drag?.offset ?? 0 : 0)
                .zIndex(drag?.id == page.id ? 1 : 0)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .global)
                        .onChanged { value in dragChanged(page.id, from: index, by: value.translation.height) }
                        .onEnded { _ in dragEnded() }
                )
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
        #if DEBUG
        .onAppear {
            if DemoData.isEnabled, DemoData.dragsPage, let first = pages.first {
                drag = PageDrag(id: first.id, from: 0, offset: Self.rowStep * 2.6)
            }
        }
        #endif
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

    // MARK: Reordering

    private func dragChanged(_ id: UUID, from index: Int, by translation: CGFloat) {
        if drag == nil {
            withAnimation(SchemaMotion.fast) { drag = PageDrag(id: id, from: index, offset: 0) }
        }
        guard drag?.id == id else { return }
        // Keep the row within the list of pages.
        let step = Self.rowStep
        let low = -CGFloat(index) * step
        let high = CGFloat(pages.count - 1 - index) * step
        drag?.offset = min(max(translation, low), high)
    }

    private func dragEnded() {
        guard let drag else { return }
        let to = targetIndex(of: drag)
        // Save the new order and let the row settle into its slot together.
        withAnimation(SchemaMotion.smooth) {
            if to != drag.from, pages.indices.contains(to) {
                listViewModel.movePage(drag.id, to: pages[to].id, in: lists)
            }
            self.drag = nil
        }
    }

    /// The slot the dragged row would land in if dropped now.
    private func targetIndex(of drag: PageDrag) -> Int {
        let moved = Int((drag.offset / Self.rowStep).rounded())
        return min(max(drag.from + moved, 0), pages.count - 1)
    }

    /// How far a row moves aside to make room for the dragged one.
    private func shift(forRowAt index: Int, id: UUID) -> CGFloat {
        guard let drag, drag.id != id else { return 0 }
        let to = targetIndex(of: drag)
        if drag.from < to, index > drag.from, index <= to { return -Self.rowStep }
        if to < drag.from, index >= to, index < drag.from { return Self.rowStep }
        return 0
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

/// A page row being dragged: where it started and how far it has moved.
private struct PageDrag: Equatable {
    let id: UUID
    let from: Int
    var offset: CGFloat
}

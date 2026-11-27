//
//  SidebarSections.swift
//  Schema
//
//  The sidebar's sections (#120): Pinned (only when something is pinned),
//  Views, Pages, Tags and Tools. Any of them can be open at once, or none;
//  they scroll together between the Today tile and the footer, which stay put.
//

import SwiftUI

enum SidebarSection: String, CaseIterable {
    case pinned, views, pages, tags, tools

    var title: String {
        switch self {
        case .pinned: "Pinned"
        case .views: "Views"
        case .pages: "Pages"
        case .tags: "Tags"
        case .tools: "Tools"
        }
    }
}

struct SidebarSections: View {
    @Environment(WorkspaceState.self) private var workspace

    let lists: [SchemaList]
    let upcomingCount: Int
    let listViewModel: ListViewModel

    @State private var open: Set<SidebarSection> = SchemaPreferences.sidebarOpenSections
    /// The row being dragged to a new place (#42, #120). Nothing is saved
    /// until the drag ends.
    @State private var drag: RowDrag?

    private var pages: [SchemaList] { listViewModel.pages(from: lists) }
    private var tagPages: [SchemaList] { listViewModel.tagPages(from: lists) }

    var body: some View {
        let pinned = listViewModel.pinnedDestinations(existingIn: lists)
        let sections = SidebarSection.allCases.filter { $0 != .pinned || !pinned.isEmpty }

        ScrollView {
            VStack(spacing: 0) {
                ForEach(sections, id: \.self) { section in
                    let isOpen = open.contains(section)
                    Rectangle()
                        .fill(SchemaTheme.line)
                        .frame(height: 1)
                    header(section, isOpen: isOpen, count: count(of: section, pinned: pinned))
                    if isOpen {
                        rows(of: section, pinned: pinned)
                            .padding(.bottom, 8)
                            // Rows fade as the sections below slide over
                            // them, the same both ways.
                            .transition(.opacity.combined(with: .offset(y: -6)))
                    }
                }
            }
            .padding(.bottom, 4)
            .themedScrollBars()
        }
        .clipped()
        .onChange(of: open) { _, sections in
            SchemaPreferences.sidebarOpenSections = sections
        }
        #if DEBUG
        .onAppear {
            if DemoData.isEnabled, let section = DemoData.sidebarSection { open = [section] }
            if DemoData.isEnabled, DemoData.dragsPage, let first = pages.first {
                open.insert(.pages)
                drag = RowDrag(key: first.id.uuidString, from: 0, offset: SidebarMetrics.rowStep * 2.6)
            }
        }
        #endif
    }

    private func toggle(_ section: SidebarSection) {
        withAnimation(SchemaMotion.smooth) {
            if open.contains(section) {
                open.remove(section)
            } else {
                open.insert(section)
            }
        }
    }

    // MARK: Headers

    private func header(_ section: SidebarSection, isOpen: Bool, count: Int?) -> some View {
        HStack(spacing: 2) {
            Button {
                toggle(section)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 10)
                    Text(section.title)
                        .font(.schemaLabel)
                        .textCase(.uppercase)
                        .tracking(0.9)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.schemaMeta)
                            .foregroundStyle(SchemaTheme.inkFaint)
                    }
                    Spacer(minLength: 4)
                }
                .foregroundStyle(isOpen ? SchemaTheme.ink : SchemaTheme.inkMuted)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isOpen ? "Hide \(section.title.lowercased())" : "Show \(section.title.lowercased())")
            .accessibilityValue(isOpen ? "Open" : "Collapsed")

            if section == .pages {
                SchemaIconButton(systemImage: "plus", label: "New page", shortcut: "⌘N", size: 28) {
                    listViewModel.openNewPage()
                }
            }
        }
        .padding(.leading, 4)
        .frame(height: 34)
    }

    private func count(of section: SidebarSection, pinned: [Destination]) -> Int? {
        switch section {
        case .pinned: pinned.count
        case .pages: pages.count
        case .tags: tagPages.count
        case .views, .tools: nil
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func rows(of section: SidebarSection, pinned: [Destination]) -> some View {
        VStack(alignment: .leading, spacing: SidebarMetrics.rowGap) {
            switch section {
            case .pinned:
                ForEach(Array(pinned.enumerated()), id: \.element) { index, destination in
                    row(for: destination, showsPin: false)
                        .sidebarReorderable(key: destination.storageKey, index: index, count: pinned.count, drag: $drag) { from, to in
                            listViewModel.movePin(pinned[from], to: pinned[to])
                        }
                }
            case .views:
                row(for: .view(.upcoming))
                row(for: .view(.everything))
            case .pages:
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    row(for: .page(page.id))
                        .sidebarReorderable(key: page.id.uuidString, index: index, count: pages.count, drag: $drag) { from, to in
                            listViewModel.movePage(pages[from].id, to: pages[to].id, in: lists)
                        }
                }
                if pages.isEmpty {
                    emptyNote("No pages yet. ⌘N makes one.")
                }
            case .tags:
                ForEach(tagPages, id: \.id) { tag in
                    row(for: .page(tag.id))
                }
                if tagPages.isEmpty {
                    emptyNote("Write #name in a line to make a tag.")
                }
            case .tools:
                PomodoroSidebarRow(
                    isActive: listViewModel.showsPomodoro,
                    isPinned: listViewModel.isPinned(.tool(.pomodoro))
                ) {
                    listViewModel.selectPomodoro()
                }
                .sidebarPinMenu("Pomodoro", destination: .tool(.pomodoro), listViewModel: listViewModel)
            }
        }
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(.schemaCaption)
            .foregroundStyle(SchemaTheme.inkFaint)
            .padding(.horizontal, SidebarMetrics.iconLeading)
            .padding(.vertical, 6)
    }

    /// A row for a page, view or tool; `showsPin` marks pinned items in
    /// their own section.
    @ViewBuilder
    private func row(for destination: Destination, showsPin: Bool = true) -> some View {
        // A task page keeps the list or view it was opened from lit (#124).
        let isActive = listViewModel.context == destination
        let isPinned = showsPin && listViewModel.isPinned(destination)
        switch destination {
        case .view(let kind):
            SidebarRow(
                title: kind.title,
                isActive: isActive,
                isPinned: isPinned,
                trailing: kind == .everything ? .keys("/") : (kind == .upcoming ? .count(upcomingCount) : .none),
                tooltip: kind == .everything ? "\(kind.title)  /" : kind.title
            ) {
                Image(systemName: kind.systemImage)
            } action: {
                listViewModel.go(to: destination)
            }
            .sidebarPinMenu(kind.title, destination: destination, listViewModel: listViewModel)
        case .tool(let kind):
            SidebarRow(title: kind.title, isActive: isActive, isPinned: isPinned, trailing: .none, tooltip: kind.title) {
                Image(systemName: kind == .pomodoro ? "timer" : "gearshape")
            } action: {
                listViewModel.go(to: destination)
            }
            .sidebarPinMenu(kind.title, destination: destination, listViewModel: listViewModel)
        case .page(let id):
            if let page = lists.first(where: { $0.id == id }) {
                pageRow(page, isActive: isActive, isPinned: isPinned)
            }
        case .task:
            EmptyView()
        }
    }

    private func pageRow(_ page: SchemaList, isActive: Bool, isPinned: Bool) -> some View {
        let destination = Destination.page(page.id)
        return SidebarRow(
            title: page.title,
            isActive: isActive,
            isPinned: isPinned,
            trailing: .none,
            tooltip: page.isTagPage ? "Tag page: lines tagged #\(page.title)" : page.pageKind.displayName
        ) {
            Image(systemName: page.pageKind.systemImage)
        } action: {
            listViewModel.selectList(page)
        }
        .schemaContextMenu(page.isTagPage ? "#\(page.title)" : page.title) {
            SchemaMenuItem.action("Open") { listViewModel.selectList(page) }
            SchemaMenuItem.action(listViewModel.isPinned(destination) ? "Unpin" : "Pin") {
                withAnimation(SchemaMotion.smooth) { listViewModel.togglePin(destination) }
            }
            SchemaMenuItem.action("Rename") {
                listViewModel.selectList(page)
                workspace.requestPageRename(page.id)
            }
            SchemaMenuItem.divider
            SchemaMenuItem.action(page.isTagPage ? "Delete tag\u{2026}" : "Delete page\u{2026}", isDestructive: true) {
                workspace.requestPageDelete(page.id)
            }
        }
    }
}

// MARK: - Pinning

private extension View {
    /// Right-click to pin or unpin a view or tool.
    func sidebarPinMenu(_ title: String, destination: Destination, listViewModel: ListViewModel) -> some View {
        schemaContextMenu(title) {
            SchemaMenuItem.action("Open") { listViewModel.go(to: destination) }
            SchemaMenuItem.action(listViewModel.isPinned(destination) ? "Unpin" : "Pin") {
                withAnimation(SchemaMotion.smooth) { listViewModel.togglePin(destination) }
            }
        }
    }
}

// MARK: - Reordering

/// A row being dragged: which one, where it started and how far it moved.
struct RowDrag: Equatable {
    let key: String
    let from: Int
    var offset: CGFloat
}

private struct SidebarReorderable: ViewModifier {
    let key: String
    let index: Int
    let count: Int
    @Binding var drag: RowDrag?
    let onMove: (Int, Int) -> Void

    private var step: CGFloat { SidebarMetrics.rowStep }
    private var isDragged: Bool { drag?.key == key }

    func body(content: Content) -> some View {
        content
            .background {
                if isDragged {
                    RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous)
                        .fill(SchemaTheme.surface)
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        .transition(.opacity)
                }
            }
            // Rows the drag passes over slide one step up or down.
            .offset(y: shift)
            .animation(SchemaMotion.smooth, value: shift)
            // The dragged row tracks the pointer exactly, unanimated.
            .offset(y: isDragged ? drag?.offset ?? 0 : 0)
            .zIndex(isDragged ? 1 : 0)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in changed(by: value.translation.height) }
                    .onEnded { _ in ended() }
            )
    }

    private func changed(by translation: CGFloat) {
        if drag == nil {
            withAnimation(SchemaMotion.fast) { drag = RowDrag(key: key, from: index, offset: 0) }
        }
        guard isDragged else { return }
        let low = -CGFloat(index) * step
        let high = CGFloat(count - 1 - index) * step
        drag?.offset = min(max(translation, low), high)
    }

    private func ended() {
        guard let current = drag, current.key == key else { return }
        let to = target(of: current)
        withAnimation(SchemaMotion.smooth) {
            if to != current.from { onMove(current.from, to) }
            drag = nil
        }
    }

    private func target(of drag: RowDrag) -> Int {
        let moved = Int((drag.offset / step).rounded())
        return min(max(drag.from + moved, 0), count - 1)
    }

    /// How far this row moves aside to make room for the dragged one.
    private var shift: CGFloat {
        guard let drag, drag.key != key else { return 0 }
        let to = target(of: drag)
        if drag.from < to, index > drag.from, index <= to { return -step }
        if to < drag.from, index >= to, index < drag.from { return step }
        return 0
    }
}

extension View {
    func sidebarReorderable(
        key: String, index: Int, count: Int, drag: Binding<RowDrag?>, onMove: @escaping (Int, Int) -> Void
    ) -> some View {
        modifier(SidebarReorderable(key: key, index: index, count: count, drag: drag, onMove: onMove))
    }
}

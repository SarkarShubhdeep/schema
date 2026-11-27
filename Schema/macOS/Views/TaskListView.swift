//
//  TaskListView.swift
//  Schema
//

import SwiftUI

/// Callbacks for row-level actions. Selection and keyboard handling go
/// through `WorkspaceState` directly.
struct TaskListActions {
    let onToggle: (SchemaTask) -> Void
    let onDelete: (SchemaTask) -> Void
    let onSetReminder: (SchemaTask, Date?) -> Void
    let onOpenDetail: (UUID) -> Void
    /// Move `taskID` so it sits before the incomplete row currently at the given index.
    let onReorder: (UUID, Int) -> Void
}

/// The task list for the selected list.
///
/// Built on `ScrollView` + `VStack` rather than `List`: on macOS, `List` (an
/// `NSTableView` underneath) re-measures rows lazily, which squished rows and
/// shifted the scroll offset when switching tabs (issue #1), and its `onMove`
/// drag needed an AppKit mouse shim that broke when the window was key
/// (issue #3). Here layout is plain SwiftUI and drag-to-reorder is a
/// `DragGesture` against measured row frames.
///
/// Rows sit directly in a `LazyVStack` so only the visible ones are built
/// (#45: a 1,000-task page). Each row draws its own slice of the section's
/// card, so the cards still read as one rounded box.
struct TaskListView<Header: View>: View {
    @Environment(WorkspaceState.self) private var workspace

    /// Identity of what is shown (page or view); a new key resets scrolling.
    let pageKey: String
    /// Page header and quick add, scrolled with the tasks.
    let header: Header
    /// Open tasks in display order: `sections` flattened.
    let incompleteTasks: [SchemaTask]
    let sections: [TaskSectionGroup]
    let completedTasks: [SchemaTask]
    let showListTags: Bool
    let taskViewModel: TaskViewModel
    let isSequenceBlocked: (SchemaTask) -> Bool
    let actions: TaskListActions
    var isTaskListFocused: FocusState<Bool>.Binding

    @State private var showCompleted = false
    /// Measured row frames for drag-to-reorder. Kept in a reference so
    /// that measuring doesn't re-render the list.
    @State private var rowFrames = RowFrameStore()
    @State private var drag: DragSession?

    private struct DragSession: Equatable {
        let taskID: UUID
        let movingIDs: Set<UUID>
        var translation: CGFloat
        var insertionIndex: Int
    }

    @Environment(\.pageContentInsets) private var contentInsets

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.bottom, TaskListMetrics.sectionSpacing)
                        content
                    }
                    .coordinateSpace(name: taskListCoordinateSpace)
                    .onPreferenceChange(RowFramePreferenceKey.self) { frames in
                        rowFrames.frames.merge(frames, uniquingKeysWith: { $1 })
                    }
                    .overlay(alignment: .topLeading) {
                        insertionIndicator
                    }
                    .frame(maxWidth: TaskListMetrics.maxContentWidth)
                    .padding(.horizontal, TaskListMetrics.horizontalInset)
                    .padding(.top, TaskListMetrics.topInset + contentInsets.top)
                    .padding(.bottom, TaskListMetrics.bottomInset + contentInsets.bottom)
                    .frame(maxWidth: .infinity)
                    .themedScrollBars()
                }
                .scrollIndicators(.automatic)
                .contentMargins(.top, contentInsets.top, for: .scrollIndicators)
                .contentMargins(.bottom, contentInsets.bottom, for: .scrollIndicators)
                .onChange(of: workspace.primarySelectedTaskID) { _, taskID in
                    guard let taskID else { return }
                    if completedTasks.contains(where: { $0.id == taskID }), !showCompleted {
                        showCompleted = true
                    }
                    withAnimation(SchemaMotion.smooth) {
                        proxy.scrollTo(taskID)
                    }
                }
            }
            // A fresh scroll view per list: switching tabs always starts at the
            // top with a clean layout instead of inheriting the old offset.
            .id(pageKey)

            Color.clear
                .allowsHitTesting(false)
                .focusable()
                .focused(isTaskListFocused)
                .focusEffectDisabled()
        }
        .background(SchemaTheme.canvas)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if incompleteTasks.isEmpty && completedTasks.isEmpty {
            ContentUnavailableView(
                "No tasks yet",
                systemImage: "checklist",
                description: Text("Press n to add your first task.")
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, group in
                sectionHeader(group)
                    .padding(.top, index == 0 ? 0 : TaskListMetrics.sectionSpacing)
                    .padding(.bottom, 8)
                ForEach(Array(group.tasks.enumerated()), id: \.element.id) { position, task in
                    incompleteRow(for: task)
                        .cardSlice(.init(index: position, count: group.tasks.count))
                }
            }

            if !completedTasks.isEmpty {
                completedHeader
                    .padding(.top, sections.isEmpty ? 0 : TaskListMetrics.sectionSpacing)
                    .padding(.bottom, 8)
                if showCompleted {
                    ForEach(Array(completedTasks.enumerated()), id: \.element.id) { position, task in
                        taskRow(for: task)
                            .id(task.id)
                            .cardSlice(.init(index: position, count: completedTasks.count), isQuiet: true)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ group: TaskSectionGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.title)
                .font(.spaceGrotesk(15, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(SchemaTheme.ink)
                .accessibilityAddTraits(.isHeader)
            SchemaBadge(count: group.tasks.count)
            Spacer(minLength: 8)
            if !group.hint.isEmpty {
                Text(group.hint)
                    .font(.schemaCaption)
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
    }

    private func incompleteRow(for task: SchemaTask) -> some View {
        let isMoving = drag?.movingIDs.contains(task.id) == true
        let canDrag = taskViewModel.canMoveTask(task, in: incompleteTasks)

        return taskRow(for: task, isLifted: isMoving)
            .id(task.id)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: RowFramePreferenceKey.self,
                        value: [task.id: geometry.frame(in: .named(taskListCoordinateSpace))]
                    )
                }
            }
            .offset(y: isMoving ? (drag?.translation ?? 0) : 0)
            .zIndex(isMoving ? 1 : 0)
            .transition(.opacity)
            .gesture(reorderGesture(for: task), including: canDrag ? .all : .subviews)
            .help(canDrag ? "" : "Follows the previous routine task — drag the first task to move the chain")
    }

    private var completedHeader: some View {
        Button {
            workspace.clearSelection()
            withAnimation(SchemaMotion.smooth) {
                showCompleted.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text("Completed")
                    .font(.spaceGrotesk(15, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(SchemaTheme.inkMuted)
                SchemaBadge(count: completedTasks.count)
                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SchemaTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }

    private func taskRow(for task: SchemaTask, isLifted: Bool = false) -> some View {
        TaskRowView(
            task: task,
            isHighlighted: workspace.highlightedTaskID == task.id,
            isKeyboardSelected: workspace.isSelected(task.id),
            isSequenceBlocked: isSequenceBlocked(task),
            showListTag: showListTags,
            isLifted: isLifted,
            onToggle: { actions.onToggle(task) },
            onDelete: { actions.onDelete(task) },
            onSetReminder: { date in actions.onSetReminder(task, date) },
            onSelect: {
                workspace.selectSingle(task.id)
                isTaskListFocused.wrappedValue = true
            },
            onDeselect: workspace.clearSelection,
            onOpenDetail: { actions.onOpenDetail(task.id) }
        )
    }

    // MARK: Drag to reorder

    private func reorderGesture(for task: SchemaTask) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(taskListCoordinateSpace))
            .onChanged { value in
                if drag == nil {
                    let group = taskViewModel.dragGroup(for: task, in: incompleteTasks)
                    drag = DragSession(
                        taskID: task.id,
                        movingIDs: Set(group.map(\.id)),
                        translation: 0,
                        insertionIndex: incompleteTasks.firstIndex(where: { $0.id == task.id }) ?? 0
                    )
                }
                guard var session = drag else { return }
                session.translation = value.translation.height
                session.insertionIndex = insertionIndex(for: session)
                drag = session
            }
            .onEnded { _ in
                guard let session = drag else { return }
                withAnimation(SchemaMotion.smooth) {
                    actions.onReorder(session.taskID, session.insertionIndex)
                    drag = nil
                }
            }
    }

    /// Index in `incompleteTasks` the dragged group would be inserted before,
    /// based on where the group's leading row midpoint currently sits.
    /// Drags stay inside their section: moving a task between Today and
    /// Someday would need a new due date, which a drag doesn't set.
    private func insertionIndex(for session: DragSession) -> Int {
        let rowFrames = rowFrames.frames
        guard let frame = rowFrames[session.taskID] else { return session.insertionIndex }
        let range = sectionRange(containing: session.taskID)
        let draggedMidY = frame.midY + session.translation

        let proposed = incompleteTasks[range].firstIndex { task in
            guard !session.movingIDs.contains(task.id),
                  let rowFrame = rowFrames[task.id] else { return false }
            return rowFrame.midY > draggedMidY
        } ?? range.upperBound

        let valid = taskViewModel.validInsertionIndex(proposed, in: incompleteTasks, excluding: session.movingIDs)
        return min(max(valid, range.lowerBound), range.upperBound)
    }

    /// Indices in `incompleteTasks` covered by the section that holds `taskID`.
    private func sectionRange(containing taskID: UUID) -> Range<Int> {
        var start = 0
        for group in sections {
            let end = start + group.tasks.count
            if group.tasks.contains(where: { $0.id == taskID }) {
                return start..<end
            }
            start = end
        }
        return 0..<incompleteTasks.count
    }

    @ViewBuilder
    private var insertionIndicator: some View {
        if let session = drag, abs(session.translation) > 4, let y = indicatorY(for: session) {
            Capsule()
                .fill(SchemaTheme.ink)
                .frame(height: 2)
                .frame(maxWidth: .infinity)
                .offset(y: y - 1)
                .allowsHitTesting(false)
        }
    }

    private func indicatorY(for session: DragSession) -> CGFloat? {
        let rowFrames = rowFrames.frames
        let index = session.insertionIndex
        let range = sectionRange(containing: session.taskID)
        if index < range.upperBound, let frame = rowFrames[incompleteTasks[index].id] {
            return frame.minY - TaskListMetrics.rowSpacing / 2
        }
        let sectionTasks = incompleteTasks[range]
        let lastStatic = sectionTasks.last { !session.movingIDs.contains($0.id) } ?? sectionTasks.last
        guard let last = lastStatic, let frame = rowFrames[last.id] else { return nil }
        return frame.maxY + TaskListMetrics.rowSpacing / 2
    }
}

private let taskListCoordinateSpace = "TaskListContent"

private enum TaskListMetrics {
    static let horizontalInset: CGFloat = 32
    static let maxContentWidth: CGFloat = ShellMetrics.contentWidth
    static let rowSpacing: CGFloat = 2
    static let sectionSpacing: CGFloat = 22
    static let topInset: CGFloat = 20
    /// Leaves room for the floating selection toolbar over the last task.
    static let bottomInset: CGFloat = 104
    static let cardPadding: CGFloat = 4
    static let cardRadius: CGFloat = 16
}

/// Where a row sits in its section's card.
private struct CardSlice {
    let isFirst: Bool
    let isLast: Bool

    init(index: Int, count: Int) {
        isFirst = index == 0
        isLast = index == count - 1
    }
}

private extension View {
    /// Pads a row as the card did and draws its part of the card: the
    /// rounded top on the first row, the rounded bottom on the last, and
    /// only the side edges in between.
    func cardSlice(_ slice: CardSlice, isQuiet: Bool = false) -> some View {
        let overhang = TaskListMetrics.cardRadius * 2
        let shape = RoundedRectangle(cornerRadius: TaskListMetrics.cardRadius, style: .continuous)
        return self
            .padding(.horizontal, TaskListMetrics.cardPadding)
            .padding(.top, slice.isFirst ? TaskListMetrics.cardPadding : TaskListMetrics.rowSpacing / 2)
            .padding(.bottom, slice.isLast ? TaskListMetrics.cardPadding : TaskListMetrics.rowSpacing / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // The whole card's shape, stretched past this row and clipped
                // to it, so corners only show where the card really ends.
                Color.clear
                    .overlay {
                        shape
                            .fill(isQuiet ? Color.clear : SchemaTheme.surface)
                            .overlay(shape.strokeBorder(SchemaTheme.line, lineWidth: 1))
                            .padding(.top, slice.isFirst ? 0 : -overhang)
                            .padding(.bottom, slice.isLast ? 0 : -overhang)
                    }
                    .clipped()
            }
    }
}

/// Row frames for drag-to-reorder, held by reference so updates don't
/// invalidate the view.
private final class RowFrameStore {
    var frames: [UUID: CGRect] = [:]
}

private struct RowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

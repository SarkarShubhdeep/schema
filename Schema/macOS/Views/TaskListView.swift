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
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var drag: DragSession?



    private struct DragSession: Equatable {
        let taskID: UUID
        let movingIDs: Set<UUID>
        var translation: CGFloat
        var insertionIndex: Int
    }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: TaskListMetrics.sectionSpacing) {
                        header
                        content
                    }
                    .frame(maxWidth: TaskListMetrics.maxContentWidth)
                    .padding(.horizontal, TaskListMetrics.horizontalInset)
                    .padding(.top, TaskListMetrics.topInset)
                    .padding(.bottom, TaskListMetrics.bottomInset)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
                .onChange(of: workspace.primarySelectedTaskID) { _, taskID in
                    guard let taskID else { return }
                    if completedTasks.contains(where: { $0.id == taskID }), !showCompleted {
                        showCompleted = true
                    }
                    withAnimation(SchemaMotion.fast) {
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
            VStack(alignment: .leading, spacing: TaskListMetrics.sectionSpacing) {
                ForEach(sections) { group in
                    sectionCard(group)
                }

                if !completedTasks.isEmpty {
                    completedCard
                }
            }
            .coordinateSpace(name: taskListCoordinateSpace)
            .onPreferenceChange(RowFramePreferenceKey.self) { rowFrames = $0 }
            .overlay(alignment: .topLeading) {
                insertionIndicator
            }
        }
    }

    private func sectionCard(_ group: TaskSectionGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(group.section.title)
                    .font(.spaceGrotesk(15, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(SchemaTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                SchemaBadge(count: group.tasks.count)
                Spacer(minLength: 8)
                if !group.section.hint.isEmpty {
                    Text(group.section.hint)
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)

            card {
                ForEach(group.tasks) { task in
                    incompleteRow(for: task)
                }
            }
        }
    }

    /// Done tasks, collapsed by default and kept quiet: no fill, faint titles.
    private var completedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            completedHeader

            if showCompleted {
                card(isQuiet: true) {
                    ForEach(completedTasks) { task in
                        taskRow(for: task)
                            .id(task.id)
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func card<Content: View>(isQuiet: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: TaskListMetrics.rowSpacing) {
            content()
        }
        .padding(TaskListMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TaskListMetrics.cardRadius, style: .continuous)
                .fill(isQuiet ? Color.clear : SchemaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskListMetrics.cardRadius, style: .continuous)
                .strokeBorder(SchemaTheme.line, lineWidth: 1)
        )
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
            withAnimation(SchemaMotion.fast) {
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
    static let maxContentWidth: CGFloat = 900
    static let rowSpacing: CGFloat = 2
    static let sectionSpacing: CGFloat = 22
    static let topInset: CGFloat = 20
    /// Leaves room for the floating selection toolbar over the last task.
    static let bottomInset: CGFloat = 104
    static let cardPadding: CGFloat = 4
    static let cardRadius: CGFloat = 16
}

private struct RowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

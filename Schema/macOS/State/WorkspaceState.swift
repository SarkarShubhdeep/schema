//
//  WorkspaceState.swift
//  Schema
//

import SwiftUI
import Observation

/// Where keyboard focus should land next. Views own the actual `@FocusState`;
/// they observe `WorkspaceState.focusRequest` and apply it in `onChange`, which
/// runs after the current update — no `DispatchQueue.main.async` hop needed.
enum WorkspaceFocus: Equatable {
    case addTask
    case taskList
    case none
}

struct DeleteRequest: Equatable {
    let taskIDs: Set<UUID>
    let token = UUID()
}

struct FocusRequest: Equatable {
    let target: WorkspaceFocus
    let token = UUID()
}

/// UI state for the main workspace window: selection, add-task bar, detail
/// panel, popovers, and pending focus changes. Data lives in SwiftData and the
/// view models; this object only holds transient presentation state.
@Observable
@MainActor
final class WorkspaceState {
    // MARK: Selection

    private(set) var selectedTaskIDs: Set<UUID> = []
    private(set) var primarySelectedTaskID: UUID?
    private var selectionAnchorID: UUID?

    // MARK: Presentation

    var highlightedTaskID: UUID?
    var showNotifications = false
    var showSettings = false
    var notificationItems: [SchemaNotificationItem] = []
    var isAddTaskExpanded = false
    var quickEntryListCandidateIndex = 0
    var taskDetailEditor: TaskDetailEditor?
    var isEditingListName = false
    var sequenceValidationAlert: RoutineSequenceValidationResult?
    var weekStart = SchemaPreferences.weekStart {
        didSet { SchemaPreferences.weekStart = weekStart }
    }
    var allowIndependentFollowerRoutineCompletion = SchemaPreferences.allowIndependentFollowerRoutineCompletion {
        didSet {
            SchemaPreferences.allowIndependentFollowerRoutineCompletion = allowIndependentFollowerRoutineCompletion
        }
    }

    // MARK: Side panels

    var isSidebarCollapsed = SchemaPreferences.isSidebarCollapsed {
        didSet { SchemaPreferences.isSidebarCollapsed = isSidebarCollapsed }
    }
    var isDetailsPanelCollapsed = SchemaPreferences.isDetailsPanelCollapsed {
        didSet { SchemaPreferences.isDetailsPanelCollapsed = isDetailsPanelCollapsed }
    }
    /// Last measured window width and its breakpoint; set by `windowWidthChanged(to:)`.
    @ObservationIgnored var windowWidth: CGFloat?
    @ObservationIgnored var windowWidthTier: WindowWidthTier?

    // MARK: Delete confirmation

    /// Tasks waiting for the delete dialog's answer; `nil` when it is closed.
    var pendingDeleteIDs: Set<UUID>?
    /// Set when the dialog is confirmed; the workspace performs the delete.
    private(set) var confirmedDelete: DeleteRequest?

    var isConfirmingDelete: Bool { pendingDeleteIDs != nil }

    func requestDelete(_ taskIDs: Set<UUID>) {
        guard !taskIDs.isEmpty else { return }
        pendingDeleteIDs = taskIDs
    }

    func confirmPendingDelete() {
        if let ids = pendingDeleteIDs {
            confirmedDelete = DeleteRequest(taskIDs: ids)
        }
        pendingDeleteIDs = nil
    }

    func cancelPendingDelete() {
        pendingDeleteIDs = nil
        requestFocus(.taskList)
    }

    // MARK: Focus

    private(set) var focusRequest: FocusRequest?

    func requestFocus(_ target: WorkspaceFocus) {
        focusRequest = FocusRequest(target: target)
    }

    func refreshNotifications(using service: any NotificationServiceProtocol) async {
        notificationItems = await service.fetchPendingReminders()
    }

    /// A task is open as a page in the main column (#31).
    var isTaskPageOpen: Bool { taskDetailEditor != nil }

    var hasDismissibleState: Bool {
        isAddTaskExpanded || !selectedTaskIDs.isEmpty
    }

    // MARK: Selection API

    func isSelected(_ taskID: UUID) -> Bool {
        selectedTaskIDs.contains(taskID)
    }

    func clearSelection() {
        selectedTaskIDs = []
        primarySelectedTaskID = nil
        selectionAnchorID = nil
    }

    func selectSingle(_ taskID: UUID) {
        selectedTaskIDs = [taskID]
        primarySelectedTaskID = taskID
        selectionAnchorID = taskID
    }

    func select(_ taskIDs: [UUID]) {
        guard let first = taskIDs.first else {
            clearSelection()
            return
        }
        selectedTaskIDs = Set(taskIDs)
        selectionAnchorID = first
        primarySelectedTaskID = taskIDs.last
    }

    /// Moves a single-item selection up or down through `orderedIDs`.
    func moveSelection(by offset: Int, in orderedIDs: [UUID]) {
        guard !orderedIDs.isEmpty else {
            clearSelection()
            return
        }

        guard let currentID = primarySelectedTaskID ?? selectedTaskIDs.first,
              let currentIndex = orderedIDs.firstIndex(of: currentID) else {
            selectSingle(orderedIDs[0])
            return
        }

        let nextIndex = max(0, min(orderedIDs.count - 1, currentIndex + offset))
        selectSingle(orderedIDs[nextIndex])
    }

    /// Shift+arrow range selection anchored at the first selected item.
    func extendSelection(by offset: Int, in orderedIDs: [UUID]) {
        guard !orderedIDs.isEmpty else {
            clearSelection()
            return
        }

        guard let primaryID = primarySelectedTaskID,
              let primaryIndex = orderedIDs.firstIndex(of: primaryID) else {
            selectSingle(orderedIDs[0])
            return
        }

        let anchorIndex = selectionAnchorID.flatMap { orderedIDs.firstIndex(of: $0) } ?? primaryIndex
        let nextPrimaryIndex = max(0, min(orderedIDs.count - 1, primaryIndex + offset))

        selectionAnchorID = orderedIDs[anchorIndex]
        primarySelectedTaskID = orderedIDs[nextPrimaryIndex]
        let lower = min(anchorIndex, nextPrimaryIndex)
        let upper = max(anchorIndex, nextPrimaryIndex)
        selectedTaskIDs = Set(orderedIDs[lower...upper])
    }

    /// Drops selected IDs that are no longer visible.
    func pruneSelection(toVisible visibleIDs: [UUID]) {
        let valid = Set(visibleIDs)
        let pruned = selectedTaskIDs.intersection(valid)
        guard pruned != selectedTaskIDs else { return }

        selectedTaskIDs = pruned
        if let primary = primarySelectedTaskID, !valid.contains(primary) {
            let next = visibleIDs.first(where: pruned.contains)
            primarySelectedTaskID = next
            selectionAnchorID = next
        }
    }

    /// Selection after removing `removedIDs` from `orderedIDs`: the item now at
    /// the position of the first removed one, clamped to the end.
    func selectNeighbor(afterRemoving removedIDs: Set<UUID>, from orderedIDs: [UUID]) {
        guard let firstRemovedIndex = orderedIDs.firstIndex(where: removedIDs.contains) else {
            clearSelection()
            return
        }

        let remaining = orderedIDs.filter { !removedIDs.contains($0) }
        guard !remaining.isEmpty else {
            clearSelection()
            return
        }
        selectSingle(remaining[min(firstRemovedIndex, remaining.count - 1)])
    }
}

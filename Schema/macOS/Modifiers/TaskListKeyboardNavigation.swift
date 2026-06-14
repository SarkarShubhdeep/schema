//
//  TaskListKeyboardNavigation.swift
//  Schema
//

import SwiftUI

struct TaskListKeyboardNavigation: ViewModifier {
    let navigableTaskIDs: [UUID]
    @Binding var selectedTaskIDs: Set<UUID>
    @Binding var primarySelectedTaskID: UUID?
    @Binding var selectionAnchorID: UUID?
    @Binding var editingTaskID: UUID?
    @FocusState.Binding var isTaskListFocused: Bool

    let isAddTaskFocused: Bool
    let isEditingListName: Bool
    let onToggleSelected: (Set<UUID>) -> Void
    let onDeleteSelected: (Set<UUID>) -> Void
    let onDuplicateSelected: (Set<UUID>) -> Void
    let onSelectAllPending: () -> Void
    let onClearSelection: () -> Void

    private var canNavigate: Bool {
        editingTaskID == nil && !isEditingListName
    }

    private var canPerformActions: Bool {
        canNavigate && !isAddTaskFocused
    }

    func body(content: Content) -> some View {
        content
            .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { press in
                guard canNavigate else { return .ignored }
                if press.modifiers.contains(.shift) {
                    extendSelection(by: -1)
                } else {
                    moveSingleSelection(by: -1)
                }
                return .handled
            }
            .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { press in
                guard canNavigate else { return .ignored }
                if press.modifiers.contains(.shift) {
                    extendSelection(by: 1)
                } else {
                    moveSingleSelection(by: 1)
                }
                return .handled
            }
            .onKeyPress(keys: [.init("a")]) { press in
                guard canPerformActions, press.modifiers.contains(.shift) else { return .ignored }
                onSelectAllPending()
                return .handled
            }
            .onKeyPress(keys: [.init("d")]) { press in
                guard canPerformActions, press.modifiers.contains(.command), !selectedTaskIDs.isEmpty else {
                    return .ignored
                }
                onDuplicateSelected(selectedTaskIDs)
                return .handled
            }
            .onKeyPress(.escape) {
                guard editingTaskID == nil, !isAddTaskFocused, !isEditingListName else {
                    return .ignored
                }
                onClearSelection()
                return .handled
            }
            .onKeyPress(keys: [.return]) { press in
                guard canPerformActions, !selectedTaskIDs.isEmpty else { return .ignored }

                if press.modifiers.contains(.shift) {
                    onToggleSelected(selectedTaskIDs)
                    return .handled
                }

                guard selectedTaskIDs.count == 1,
                      let taskID = primarySelectedTaskID ?? selectedTaskIDs.first else {
                    return .ignored
                }

                editingTaskID = taskID
                isTaskListFocused = false
                return .handled
            }
            .onKeyPress { press in
                guard canPerformActions, !selectedTaskIDs.isEmpty else { return .ignored }

                let isBackspace = press.key == .delete
                    || press.characters == "\u{8}"
                    || press.characters == "\u{7F}"

                guard isBackspace else { return .ignored }

                onDeleteSelected(selectedTaskIDs)
                return .handled
            }
    }

    private func moveSingleSelection(by offset: Int) {
        guard !navigableTaskIDs.isEmpty else {
            onClearSelection()
            return
        }

        let currentID = primarySelectedTaskID ?? selectedTaskIDs.first

        if currentID == nil {
            let first = navigableTaskIDs[0]
            selectSingle(first)
            return
        }

        guard let currentIndex = navigableTaskIDs.firstIndex(of: currentID!) else {
            selectSingle(navigableTaskIDs[0])
            return
        }

        let nextIndex = max(0, min(navigableTaskIDs.count - 1, currentIndex + offset))
        selectSingle(navigableTaskIDs[nextIndex])
    }

    private func extendSelection(by offset: Int) {
        guard !navigableTaskIDs.isEmpty else {
            onClearSelection()
            return
        }

        if primarySelectedTaskID == nil {
            selectSingle(navigableTaskIDs[0])
            return
        }

        if selectionAnchorID == nil {
            selectionAnchorID = primarySelectedTaskID
        }

        guard let primaryID = primarySelectedTaskID,
              let anchorID = selectionAnchorID,
              let primaryIndex = navigableTaskIDs.firstIndex(of: primaryID),
              let anchorIndex = navigableTaskIDs.firstIndex(of: anchorID) else {
            selectSingle(navigableTaskIDs[0])
            return
        }

        let nextPrimaryIndex = max(0, min(navigableTaskIDs.count - 1, primaryIndex + offset))
        let nextPrimaryID = navigableTaskIDs[nextPrimaryIndex]
        primarySelectedTaskID = nextPrimaryID

        let lower = min(anchorIndex, nextPrimaryIndex)
        let upper = max(anchorIndex, nextPrimaryIndex)
        selectedTaskIDs = Set(navigableTaskIDs[lower...upper])
        isTaskListFocused = true
    }

    private func selectSingle(_ taskID: UUID) {
        selectedTaskIDs = [taskID]
        primarySelectedTaskID = taskID
        selectionAnchorID = taskID
        isTaskListFocused = true
    }
}

extension View {
    func taskListKeyboardNavigation(
        navigableTaskIDs: [UUID],
        selectedTaskIDs: Binding<Set<UUID>>,
        primarySelectedTaskID: Binding<UUID?>,
        selectionAnchorID: Binding<UUID?>,
        editingTaskID: Binding<UUID?>,
        isTaskListFocused: FocusState<Bool>.Binding,
        isAddTaskFocused: Bool,
        isEditingListName: Bool,
        onToggleSelected: @escaping (Set<UUID>) -> Void,
        onDeleteSelected: @escaping (Set<UUID>) -> Void,
        onDuplicateSelected: @escaping (Set<UUID>) -> Void,
        onSelectAllPending: @escaping () -> Void,
        onClearSelection: @escaping () -> Void
    ) -> some View {
        modifier(
            TaskListKeyboardNavigation(
                navigableTaskIDs: navigableTaskIDs,
                selectedTaskIDs: selectedTaskIDs,
                primarySelectedTaskID: primarySelectedTaskID,
                selectionAnchorID: selectionAnchorID,
                editingTaskID: editingTaskID,
                isTaskListFocused: isTaskListFocused,
                isAddTaskFocused: isAddTaskFocused,
                isEditingListName: isEditingListName,
                onToggleSelected: onToggleSelected,
                onDeleteSelected: onDeleteSelected,
                onDuplicateSelected: onDuplicateSelected,
                onSelectAllPending: onSelectAllPending,
                onClearSelection: onClearSelection
            )
        )
    }
}

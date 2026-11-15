//
//  TaskListKeyboardNavigation.swift
//  Schema
//

import SwiftUI

/// Actions the task list keyboard handler can trigger on the current selection.
struct TaskListKeyboardActions {
    let onToggleSelected: (Set<UUID>) -> Void
    let onDeleteSelected: (Set<UUID>) -> Void
    let onDuplicateSelected: (Set<UUID>) -> Void
    let onSelectAllPending: () -> Void
    let onOpenDetail: (UUID) -> Void
}

struct TaskListKeyboardNavigation: ViewModifier {
    @Environment(WorkspaceState.self) private var workspace

    let navigableTaskIDs: [UUID]
    let isAddTaskFocused: Bool
    @FocusState.Binding var isTaskListFocused: Bool
    let actions: TaskListKeyboardActions

    private var canNavigate: Bool {
        !workspace.isEditingListName && !workspace.isConfirmingDelete
    }

    private var canPerformActions: Bool {
        canNavigate && !isAddTaskFocused
    }

    private var selection: Set<UUID> {
        workspace.selectedTaskIDs
    }

    func body(content: Content) -> some View {
        content
            .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { press in
                arrow(-1, extending: press.modifiers.contains(.shift))
            }
            .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { press in
                arrow(1, extending: press.modifiers.contains(.shift))
            }
            .onKeyPress(keys: [.init("a")]) { press in
                guard canPerformActions, press.modifiers.contains(.shift) else { return .ignored }
                actions.onSelectAllPending()
                return .handled
            }
            .onKeyPress(keys: [.init("d")]) { press in
                guard canPerformActions, press.modifiers.contains(.command), !selection.isEmpty else {
                    return .ignored
                }
                actions.onDuplicateSelected(selection)
                return .handled
            }
            .onKeyPress(.escape) {
                guard !workspace.isEditingDetail, !isAddTaskFocused, canNavigate else {
                    return .ignored
                }
                workspace.clearSelection()
                return .handled
            }
            .onKeyPress(keys: [.return]) { press in
                guard canPerformActions, !selection.isEmpty else { return .ignored }

                if press.modifiers.contains(.shift) {
                    actions.onToggleSelected(selection)
                    return .handled
                }

                if press.modifiers.contains(.command) {
                    guard !workspace.isEditingDetail,
                          selection.count == 1,
                          let taskID = workspace.primarySelectedTaskID ?? selection.first else {
                        return .ignored
                    }
                    actions.onOpenDetail(taskID)
                    return .handled
                }

                return .ignored
            }
            .onKeyPress { press in
                guard canPerformActions, !selection.isEmpty else { return .ignored }

                let isBackspace = press.key == .delete
                    || press.characters == "\u{8}"
                    || press.characters == "\u{7F}"

                guard isBackspace else { return .ignored }

                actions.onDeleteSelected(selection)
                return .handled
            }
    }

    private func arrow(_ offset: Int, extending: Bool) -> KeyPress.Result {
        guard canNavigate else { return .ignored }
        if extending {
            workspace.extendSelection(by: offset, in: navigableTaskIDs)
        } else {
            workspace.moveSelection(by: offset, in: navigableTaskIDs)
        }
        isTaskListFocused = true
        return .handled
    }
}

extension View {
    func taskListKeyboardNavigation(
        navigableTaskIDs: [UUID],
        isAddTaskFocused: Bool,
        isTaskListFocused: FocusState<Bool>.Binding,
        actions: TaskListKeyboardActions
    ) -> some View {
        modifier(
            TaskListKeyboardNavigation(
                navigableTaskIDs: navigableTaskIDs,
                isAddTaskFocused: isAddTaskFocused,
                isTaskListFocused: isTaskListFocused,
                actions: actions
            )
        )
    }
}

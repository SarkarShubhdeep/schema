//
//  KeyboardShortcuts.swift
//  Schema
//

import SwiftUI

struct WorkspaceKeyboardShortcuts: ViewModifier {
    @Environment(WorkspaceState.self) private var workspace
    @Binding var isAddTaskExpanded: Bool
    @FocusState.Binding var isAddTaskFocused: Bool

    let canUndo: Bool
    /// False while a page that is all text (a scratchpad) is shown: single
    /// keys like N and / are typing there, and ⌘Z undoes typing.
    var allowsSingleKeyShortcuts = true
    let onSelectNextList: () -> Void
    let onSelectPreviousList: () -> Void
    let onSelectEverythingList: () -> Void
    let onCreateList: () -> Void
    let onCloseAddTask: () -> Void
    let onUndo: () -> Void

    func body(content: Content) -> some View {
        content
            .background(hiddenShortcutButtons)
    }

    private func openAddTask() {
        isAddTaskExpanded = true
        DispatchQueue.main.async {
            isAddTaskFocused = true
        }
    }

    @ViewBuilder
    private var hiddenShortcutButtons: some View {
        Group {
            if allowsSingleKeyShortcuts {
                Button("Open Add Task", action: openAddTask)
                    .keyboardShortcut("n", modifiers: [])
                    .hidden()

                Button("Close Add Task", action: onCloseAddTask)
                    .keyboardShortcut(.cancelAction)
                    .hidden()

                Button("Undo", action: onUndo)
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!canUndo)
                    .hidden()

                Button("Select Everything List", action: onSelectEverythingList)
                    .keyboardShortcut("/", modifiers: [])
                    .hidden()
            }

            Button("Select Next List", action: onSelectNextList)
                .keyboardShortcut(.tab, modifiers: .control)
                .hidden()

            Button("Select Previous List", action: onSelectPreviousList)
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .hidden()

            Button("New List", action: onCreateList)
                .keyboardShortcut("n", modifiers: .command)
                .hidden()
        }
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
        // The delete dialog owns the keyboard while it is open (Esc cancels it).
        .disabled(workspace.isConfirmingDelete)
    }
}

extension View {
    func workspaceKeyboardShortcuts(
        isAddTaskExpanded: Binding<Bool>,
        isAddTaskFocused: FocusState<Bool>.Binding,
        canUndo: Bool,
        allowsSingleKeyShortcuts: Bool = true,
        onSelectNextList: @escaping () -> Void,
        onSelectPreviousList: @escaping () -> Void,
        onSelectEverythingList: @escaping () -> Void,
        onCreateList: @escaping () -> Void,
        onCloseAddTask: @escaping () -> Void,
        onUndo: @escaping () -> Void
    ) -> some View {
        modifier(
            WorkspaceKeyboardShortcuts(
                isAddTaskExpanded: isAddTaskExpanded,
                isAddTaskFocused: isAddTaskFocused,
                canUndo: canUndo,
                allowsSingleKeyShortcuts: allowsSingleKeyShortcuts,
                onSelectNextList: onSelectNextList,
                onSelectPreviousList: onSelectPreviousList,
                onSelectEverythingList: onSelectEverythingList,
                onCreateList: onCreateList,
                onCloseAddTask: onCloseAddTask,
                onUndo: onUndo
            )
        )
    }
}

//
//  KeyboardShortcuts.swift
//  Schema
//

import SwiftUI

struct WorkspaceKeyboardShortcuts: ViewModifier {
    @Environment(WorkspaceState.self) private var workspace
    @Binding var isAddTaskExpanded: Bool
    @FocusState.Binding var isAddTaskFocused: Bool

    /// Number of pages; ⌘1–⌘9 select the first nine.
    let pageCount: Int
    let canUndo: Bool
    let onSelectListAtIndex: (Int) -> Void
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

            Button("Select Next List", action: onSelectNextList)
                .keyboardShortcut(.tab, modifiers: .control)
                .hidden()

            Button("Select Previous List", action: onSelectPreviousList)
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .hidden()

            Button("Select Everything List", action: onSelectEverythingList)
                .keyboardShortcut("/", modifiers: [])
                .hidden()

            Button("New List", action: onCreateList)
                .keyboardShortcut("n", modifiers: .command)
                .hidden()

            ForEach(0..<9, id: \.self) { index in
                if index < pageCount {
                    Button("Select Page \(index + 1)") {
                        onSelectListAtIndex(index)
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
                    .hidden()
                }
            }
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
        pageCount: Int,
        canUndo: Bool,
        onSelectListAtIndex: @escaping (Int) -> Void,
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
                pageCount: pageCount,
                canUndo: canUndo,
                onSelectListAtIndex: onSelectListAtIndex,
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

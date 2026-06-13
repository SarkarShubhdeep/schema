//
//  KeyboardShortcuts.swift
//  Schema
//

import SwiftUI

struct WorkspaceKeyboardShortcuts: ViewModifier {
    @Binding var isAddTaskExpanded: Bool
    @FocusState.Binding var isAddTaskFocused: Bool

    let lists: [SchemaList]
    let onSelectListAtIndex: (Int) -> Void
    let onCreateList: () -> Void
    let onCloseAddTask: () -> Void

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

            Button("New List", action: onCreateList)
                .keyboardShortcut("n", modifiers: .command)
                .hidden()

            ForEach(0..<9, id: \.self) { index in
                if lists.indices.contains(index) {
                    Button("Select List \(index + 1)") {
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
    }
}

extension View {
    func workspaceKeyboardShortcuts(
        isAddTaskExpanded: Binding<Bool>,
        isAddTaskFocused: FocusState<Bool>.Binding,
        lists: [SchemaList],
        onSelectListAtIndex: @escaping (Int) -> Void,
        onCreateList: @escaping () -> Void,
        onCloseAddTask: @escaping () -> Void
    ) -> some View {
        modifier(
            WorkspaceKeyboardShortcuts(
                isAddTaskExpanded: isAddTaskExpanded,
                isAddTaskFocused: isAddTaskFocused,
                lists: lists,
                onSelectListAtIndex: onSelectListAtIndex,
                onCreateList: onCreateList,
                onCloseAddTask: onCloseAddTask
            )
        )
    }
}

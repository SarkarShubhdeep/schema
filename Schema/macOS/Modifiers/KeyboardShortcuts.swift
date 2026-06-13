//
//  KeyboardShortcuts.swift
//  Schema
//

import SwiftUI

struct WorkspaceKeyboardShortcuts: ViewModifier {
    @FocusState.Binding var isQuickEntryFocused: Bool

    let lists: [SchemaList]
    let onSelectListAtIndex: (Int) -> Void
    let onCreateList: () -> Void
    let onSubmitQuickEntry: () -> Void

    func body(content: Content) -> some View {
        content
            .background(hiddenShortcutButtons)
            .onKeyPress(keys: [.init("n")]) { _ in
                guard !isQuickEntryFocused else { return .ignored }
                isQuickEntryFocused = true
                return .handled
            }
            .onKeyPress(.escape) {
                isQuickEntryFocused = false
                return .handled
            }
    }

    @ViewBuilder
    private var hiddenShortcutButtons: some View {
        Group {
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
        isQuickEntryFocused: FocusState<Bool>.Binding,
        lists: [SchemaList],
        onSelectListAtIndex: @escaping (Int) -> Void,
        onCreateList: @escaping () -> Void,
        onSubmitQuickEntry: @escaping () -> Void
    ) -> some View {
        modifier(
            WorkspaceKeyboardShortcuts(
                isQuickEntryFocused: isQuickEntryFocused,
                lists: lists,
                onSelectListAtIndex: onSelectListAtIndex,
                onCreateList: onCreateList,
                onSubmitQuickEntry: onSubmitQuickEntry
            )
        )
    }
}

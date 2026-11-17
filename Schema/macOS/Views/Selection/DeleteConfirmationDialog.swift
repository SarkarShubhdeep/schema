//
//  DeleteConfirmationDialog.swift
//  Schema
//
//  The one question before deleting tasks or a page: a small card over a
//  dimmed window. Esc or a click outside cancels; the red button deletes.
//

import SwiftUI

struct DeleteConfirmationDialog: View {
    let title: String
    let message: String
    let cta: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)

            card
                .padding(24)
        }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.spaceGrotesk(20, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(SchemaTheme.ink)
                .padding(.trailing, 40)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.schemaBody)
                .foregroundStyle(SchemaTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    HStack(spacing: 8) {
                        Text("Cancel")
                        SchemaKeyHint("Esc")
                    }
                }
                .buttonStyle(.schema(.ghost))
                .keyboardShortcut(.cancelAction)

                Button(cta, action: onConfirm)
                    .buttonStyle(DestructiveButtonStyle())
            }
            .padding(.top, 14)
        }
        .padding(24)
        .frame(maxWidth: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SchemaTheme.surface)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        )
        .overlay(alignment: .topTrailing) {
            SchemaIconButton(systemImage: "xmark", label: "Close", shortcut: "Esc", size: 32, isFilled: true, action: onCancel)
                .padding(14)
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onAppear { isFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(title)
    }
}

extension DeleteConfirmationDialog {
    /// Deleting selected tasks; ⌘Z brings them back.
    init(taskCount count: Int, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        self.init(
            title: count == 1 ? "Delete this task?" : "Delete \(count) tasks?",
            message: "You can undo this with ⌘Z. Reminders for \(count == 1 ? "this task" : "these tasks") are cancelled.",
            cta: count == 1 ? "Delete task" : "Delete \(count) tasks",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }

    /// Deleting a page and everything on it (#42). There is no undo.
    init(page: SchemaList, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        let contents: String
        if page.isScratchpad {
            contents = "Its notes are deleted with it."
        } else {
            let count = page.tasks.count
            contents = count == 0
                ? "It has no tasks."
                : "Its \(count == 1 ? "task" : "\(count) tasks") \(count == 1 ? "is" : "are") deleted with it, and \(count == 1 ? "its reminder is" : "their reminders are") cancelled."
        }
        self.init(
            title: "Delete \u{201C}\(page.title)\u{201D}?",
            message: contents + " This can\u{2019}t be undone.",
            cta: "Delete page",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Filled red pill for the confirm button. Only used for deleting.
private struct DestructiveButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.satoshi(14, weight: .bold, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.canvas)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 20)
            .frame(height: 40)
            .background(Capsule(style: .continuous).fill(SchemaTheme.danger.opacity(isHovered ? 0.88 : 1)))
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(SchemaMotion.fast, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

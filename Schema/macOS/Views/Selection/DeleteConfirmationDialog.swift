//
//  DeleteConfirmationDialog.swift
//  Schema
//
//  The one question before deleting tasks: a small card over a dimmed
//  window. Esc or a click outside cancels; the red button deletes.
//

import SwiftUI

struct DeleteConfirmationDialog: View {
    let count: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    private var title: String { count == 1 ? "Delete this task?" : "Delete \(count) tasks?" }
    private var cta: String { count == 1 ? "Delete task" : "Delete \(count) tasks" }

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

            Text("You can undo this with ⌘Z. Reminders for \(count == 1 ? "this task" : "these tasks") are cancelled.")
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

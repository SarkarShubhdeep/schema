//
//  QuickNoteView.swift
//  Schema
//
//  The Quick note card, as on the canvas: a header with the target page,
//  the note, and a footer with the keys and Save note.
//

import AppKit
import SwiftUI

struct QuickNoteView: View {
    @Bindable var model: QuickNoteModel
    let onSave: (_ asTask: Bool) -> Void
    let onClose: () -> Void

    private var isEmpty: Bool {
        model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label("Quick note", systemImage: "pencil")
                    .font(.satoshi(13, weight: .bold, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.ink)
                Spacer(minLength: 8)
                Menu {
                    ForEach(model.scratchpads) { page in
                        Button(page.title) {
                            model.targetID = page.id
                            SchemaPreferences.quickNotePageID = page.id
                        }
                    }
                    if model.scratchpads.isEmpty {
                        Text("A new Ideas scratchpad will be made")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Into: \(model.targetTitle)")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.satoshi(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Scratchpad the note goes to")
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.top, 12)

            BlockTextView(
                text: model.text,
                style: BlockTextStyle(font: .schemaText(17), color: NSColor(SchemaTheme.ink), lineHeight: 26),
                placeholder: "Write a note…",
                focusRequest: model.focusToken,
                blockID: QuickNoteModel.fieldID,
                onTextChange: { model.text = $0 },
                onReturn: { _ in if !isEmpty { onSave(false) } },
                onBackspaceAtStart: {},
                onArrowOut: { _ in },
                onFocusChange: { _ in },
                onEscape: onClose
            )
            .frame(minHeight: 78, alignment: .top)
            .frame(maxHeight: 182)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .accessibilityLabel("Note")

            Rectangle().fill(SchemaTheme.line).frame(height: 1)

            HStack(spacing: 8) {
                Text("Return saves · ⇧Return new line · ⌘Return saves as a task · Esc closes")
                    .font(.satoshi(12, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Save as task") { onSave(true) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isEmpty)
                    .hidden()
                    .frame(width: 0)
                    .accessibilityHidden(true)
                Button("Save note") { onSave(false) }
                    .buttonStyle(.schema(.primary))
                    .disabled(isEmpty)
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SchemaTheme.surface)
                // A wide soft shadow and a tight contact one. The window
                // leaves room around the card so neither is cut off.
                .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SchemaTheme.line, lineWidth: 1)
        )
        .padding(.horizontal, QuickNoteView.shadowRoom)
        .padding(.top, QuickNoteView.shadowRoom - 12)
        .padding(.bottom, QuickNoteView.shadowRoom + 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick note")
    }

    /// Clear space around the card inside the window, so the shadow fades
    /// out before the window edge instead of being clipped by it.
    static let shadowRoom: CGFloat = 60
}

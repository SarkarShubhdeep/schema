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
    /// Save the note; asTask for ⌘Return. The editor sends the note with
    /// Return, which may be newer than the last change it reported.
    let onSave: (_ asTask: Bool, _ json: String?) -> Void
    let onClose: () -> Void

    private var isEmpty: Bool { model.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label("Quick note", systemImage: "pencil")
                    .font(.satoshi(13, weight: .bold, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.ink)
                Spacer(minLength: 8)
                SchemaMenuButton("Scratchpad the note goes to") {
                    SchemaMenuItem.header("Save into")
                    for page in model.scratchpads {
                        SchemaMenuItem.action(page.title, isChecked: page.id == model.targetID) {
                            model.targetID = page.id
                            SchemaPreferences.quickNotePageID = page.id
                        }
                    }
                    if model.scratchpads.isEmpty {
                        SchemaMenuItem.action("A new Ideas scratchpad will be made", isDisabled: true) {}
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
                .fixedSize()
                .help("Scratchpad the note goes to")
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.top, 12)

            // The page editor (#82): markdown, @ mentions and lists as on a
            // page; Return saves, ⇧Return starts a new line.
            TipTapEditorView(
                documentJSON: model.documentJSON,
                documentKey: model.documentKey,
                focusRequest: model.focusRequest,
                onChange: { json, key in
                    if key == model.documentKey { model.setNote(json) }
                },
                onEscape: onClose,
                mode: .note,
                onSubmit: { json, asTask in onSave(asTask, json) },
                mentionContextJSON: model.mentionContextJSON
            )
            .frame(height: 104)
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
                Button("Save as task") { onSave(true, nil) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isEmpty)
                    .hidden()
                    .frame(width: 0)
                    .accessibilityHidden(true)
                Button("Save note") { onSave(false, nil) }
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

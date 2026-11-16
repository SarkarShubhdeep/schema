//
//  SlashMenuView.swift
//  Schema
//
//  The block menu under a line: typing / at the start of a line opens it
//  and the letters after / filter it; ⌘/ opens it to change the line's
//  kind. ↑ ↓ move, Return chooses, Esc closes. Matches the canvas.
//

import SwiftUI

struct SlashMenuView: View {
    let editor: BlockEditor
    let block: SchemaBlock

    var body: some View {
        let items = editor.menuItems
        let selection = editor.slashMenu?.selection ?? 0
        VStack(alignment: .leading, spacing: 2) {
            Text(editor.slashMenu?.mode == .turnInto ? "TURN INTO" : "BLOCKS")
                .font(.schemaLabel)
                .tracking(0.88)
                .foregroundStyle(SchemaTheme.inkMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            ForEach(Array(items.enumerated()), id: \.element) { index, kind in
                SlashMenuRow(
                    kind: kind,
                    isSelected: index == selection,
                    isCurrent: editor.slashMenu?.mode == .turnInto && kind == block.kind
                ) {
                    editor.chooseMenuItem(kind, in: block)
                } onHover: {
                    editor.selectMenuItem(at: index)
                }
            }
        }
        .padding(6)
        .frame(width: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SchemaTheme.surface)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SchemaTheme.line, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Insert block")
    }
}

private struct SlashMenuRow: View {
    let kind: BlockKind
    let isSelected: Bool
    let isCurrent: Bool
    let action: () -> Void
    let onHover: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(kind.menuGlyph)
                    .font(.satoshi(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(SchemaTheme.line, lineWidth: 1)
                    )
                Text(kind.menuTitle)
                    .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.ink)
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SchemaTheme.inkMuted)
                } else if !kind.markdownHint.isEmpty {
                    Text(kind.markdownHint)
                        .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? SchemaTheme.surfaceHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { if $0 { onHover() } }
        .accessibilityLabel(kind.menuTitle)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

extension BlockKind {
    var menuGlyph: String {
        switch self {
        case .text: "T"
        case .heading: "H"
        case .bullet: "•"
        case .todo: "○"
        case .quote: "“"
        case .divider: "—"
        }
    }

    /// The markdown shortcut shown beside each kind.
    var markdownHint: String {
        switch self {
        case .text: ""
        case .heading: "#"
        case .bullet: "-"
        case .todo: "[]"
        case .quote: ">"
        case .divider: "---"
        }
    }
}

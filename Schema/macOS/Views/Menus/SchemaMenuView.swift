//
//  SchemaMenuView.swift
//  Schema
//
//  How a Schema menu looks (#83, Menus board): a surface panel with a
//  hairline border, 12 pt corners and a soft shadow; 30 pt rows; the hover
//  fill for the pointer and arrow keys, plus the focus ring for the keyboard;
//  checks on the left, shortcuts and › on the right in Space Grotesk; Delete
//  in red. The same look as the editor's menus (editor.css).
//

import SwiftUI

struct SchemaMenuView: View {
    let model: SchemaMenuModel
    var minWidth: CGFloat = 0

    /// Reserve the check column only in menus that have checks.
    private var hasChecks: Bool { model.items.contains(where: \.isChecked) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                row(item, index: index)
            }
        }
        .padding(6)
        .frame(minWidth: max(200, minWidth), maxWidth: 320, alignment: .leading)
        .fixedSize()
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SchemaTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .coordinateSpace(name: "schemaMenu")
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.label)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private func row(_ item: SchemaMenuItem, index: Int) -> some View {
        switch item.kind {
        case .divider:
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(height: 1)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .accessibilityHidden(true)
        case .header:
            Text(item.title.uppercased())
                .font(.spaceGrotesk(11, weight: .semibold, relativeTo: .caption2))
                .tracking(0.88)
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
        case .action, .submenu:
            SchemaMenuRow(
                item: item,
                hasChecks: hasChecks,
                isSelected: model.navigator.selected == index,
                showsFocusRing: model.byKeyboard && model.navigator.selected == index,
                onHover: { model.onHover($0 ? index : nil) },
                onChoose: { model.onChoose(index) }
            )
            .background(GeometryReader { proxy in
                Color.clear.onAppear { model.rowFrames[index] = proxy.frame(in: .named("schemaMenu")) }
            })
        }
    }
}

private struct SchemaMenuRow: View {
    let item: SchemaMenuItem
    let hasChecks: Bool
    let isSelected: Bool
    let showsFocusRing: Bool
    let onHover: (Bool) -> Void
    let onChoose: () -> Void

    private var ink: Color {
        if item.isDisabled { return SchemaTheme.inkFaint }
        return item.isDestructive ? SchemaTheme.danger : SchemaTheme.ink
    }

    private var trail: String? {
        item.submenu != nil ? "\u{203A}" : item.shortcut
    }

    var body: some View {
        HStack(spacing: 8) {
            if hasChecks {
                Text(item.isChecked ? "\u{2713}" : "")
                    .font(.satoshi(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(ink)
                    .frame(width: 14, alignment: .leading)
                    .accessibilityHidden(true)
            }
            Text(item.title)
                .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                .foregroundStyle(ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trail {
                Text(trail)
                    .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(item.isDestructive && !item.isDisabled ? SchemaTheme.danger : SchemaTheme.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 30)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? SchemaTheme.surfaceHover : .clear)
        )
        .overlay {
            if showsFocusRing {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(SchemaTheme.focusRing, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        // Clicks are taken by SchemaMenuPresenter before they get here.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isChecked ? "Selected" : "")
        .accessibilityHint(item.submenu != nil ? "Opens a submenu" : (item.shortcut.map { "Shortcut \($0)" } ?? ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityRemoveTraits(item.isDisabled ? .isButton : [])
        .accessibilityAction { if !item.isDisabled { onChoose() } }
    }
}

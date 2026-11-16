//
//  BlockRowView.swift
//  Schema
//
//  One block in the editor: a hover gutter (+ adds a line below), the
//  bullet, checkbox or quote mark the kind needs, and the editable text.
//  Right-click to turn it into another kind or delete it.
//

import AppKit
import SwiftUI

struct BlockRowView: View {
    let block: SchemaBlock
    let editor: BlockEditor
    let placeholder: String
    var taskActions: BlockTaskActions?

    @State private var isHovered = false

    private enum Metrics {
        static let gutterWidth: CGFloat = 32
        static let markerWidth: CGFloat = 22
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            gutter
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.top, block.kind == .heading ? 12 : 0)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu { menu }
        .overlay(alignment: .topLeading) {
            if editor.isMenuOpen(on: block) {
                SlashMenuView(editor: editor, block: block)
                    .offset(x: Metrics.gutterWidth, y: lineHeight + 8 + (block.kind == .heading ? 12 : 0))
                    .transition(.opacity)
            }
        }
    }

    // MARK: Gutter

    private var gutter: some View {
        Button {
            editor.addBlock(below: block)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SchemaTheme.inkFaint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add a line below")
        .accessibilityLabel("Add a line below")
        .frame(width: Metrics.gutterWidth, height: lineHeight, alignment: .leading)
        .opacity(isHovered || editor.activeBlockID == block.id ? 1 : 0)
        .animation(SchemaMotion.fast, value: isHovered)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .divider:
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
                .frame(height: lineHeight)
                .accessibilityLabel("Divider")
        case .bullet:
            HStack(alignment: .top, spacing: 0) {
                Text("•")
                    .font(.satoshi(15, relativeTo: .body))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .frame(width: Metrics.markerWidth, height: lineHeight, alignment: .leading)
                    .accessibilityHidden(true)
                textView
            }
        case .todo:
            HStack(alignment: .top, spacing: 0) {
                SchemaCheckbox(
                    isChecked: editor.isChecked(block, actions: taskActions),
                    size: 16,
                    label: block.text,
                    hitPadding: 3
                ) {
                    editor.toggleChecked(block, actions: taskActions)
                }
                .frame(width: Metrics.markerWidth + 4, height: lineHeight, alignment: .leading)
                textView
                taskAccessory
            }
        case .quote:
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(SchemaTheme.line)
                    .frame(width: 2)
                    .accessibilityHidden(true)
                textView
            }
            .fixedSize(horizontal: false, vertical: true)
        case .text, .heading:
            textView
        }
    }

    private var textView: some View {
        BlockTextView(
            text: block.text,
            style: style,
            placeholder: placeholder,
            focusRequest: editor.focusRequest,
            blockID: block.id,
            isMenuOpen: editor.isMenuOpen(on: block),
            onTextChange: { editor.userTyped($0, in: block) },
            onReturn: { editor.splitBlock(block, at: $0) },
            onBackspaceAtStart: { editor.backspaceAtStart(of: block) },
            onArrowOut: { forward in
                if forward { editor.focusNext(of: block) } else { editor.focusPrevious(of: block) }
            },
            onFocusChange: { focused in
                if focused {
                    editor.activeBlockID = block.id
                    // Moving to another line closes a menu left open elsewhere.
                    if let menu = editor.slashMenu, menu.blockID != block.id { editor.dismissMenu() }
                } else if editor.activeBlockID == block.id {
                    editor.activeBlockID = nil
                }
            },
            onMenuMove: { editor.moveMenuSelection(by: $0) },
            onMenuChoose: { editor.chooseMenuItem(in: block) },
            onMenuDismiss: { editor.dismissMenu() },
            onTurnInto: { editor.openTurnInto(for: block) },
            onEscape: editor.onEscape
        )
        .accessibilityLabel(accessibilityName)
    }

    // MARK: Task link (#40)

    /// A linked line shows where its task lives; an open to-do shows
    /// "Make task in …" while hovered or being edited.
    @ViewBuilder
    private var taskAccessory: some View {
        if let task = editor.linkedTask(for: block, actions: taskActions), let actions = taskActions {
            Button {
                actions.openTask(task)
            } label: {
                HStack(spacing: 4) {
                    Text("Task in \(task.list?.title ?? "a page")")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.satoshi(12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Capsule(style: .continuous).fill(SchemaTheme.surfaceHover))
                .fixedSize()
            }
            .buttonStyle(.plain)
            .help("Open the task in \(task.list?.title ?? "its page")")
            .padding(.leading, 8)
            .padding(.top, 1)
        } else if let actions = taskActions, let page = actions.defaultPage ?? actions.taskPages.first,
                  !block.isChecked, editor.canMakeTask(from: block, actions: actions),
                  isHovered || editor.activeBlockID == block.id {
            Button {
                editor.makeTask(from: block, in: page, actions: actions)
            } label: {
                Text("Make task in \(page.title)")
                    .font(.satoshi(12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
                    .contentShape(Capsule())
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .help("Add this line as a task in \(page.title). It stays here too.")
            .padding(.leading, 8)
            .transition(.opacity)
        }
    }

    // MARK: Menu

    @ViewBuilder
    private var menu: some View {
        Menu("Turn into") {
            ForEach(BlockKind.allCases, id: \.self) { kind in
                Button {
                    editor.setKind(kind, of: block)
                } label: {
                    if kind == block.kind {
                        Label(kind.menuTitle, systemImage: "checkmark")
                    } else {
                        Text(kind.menuTitle)
                    }
                }
            }
        }
        if let actions = taskActions, editor.canMakeTask(from: block, actions: actions) {
            Menu("Make task in") {
                ForEach(actions.taskPages) { page in
                    Button(page.title) { editor.makeTask(from: block, in: page, actions: actions) }
                }
            }
        }
        if let task = editor.linkedTask(for: block, actions: taskActions), let actions = taskActions {
            Button("Open task in \(task.list?.title ?? "its page")") { actions.openTask(task) }
        }
        Button("Add a line below") { editor.addBlock(below: block) }
        Divider()
        Button("Delete", role: .destructive) { editor.remove(block) }
    }

    // MARK: Style

    private var lineHeight: CGFloat { style.lineHeight }

    private var style: BlockTextStyle {
        switch block.kind {
        case .heading:
            BlockTextStyle(font: .schemaDisplay(19, weight: .semibold), color: NSColor(SchemaTheme.ink), lineHeight: 26)
        case .quote:
            BlockTextStyle(font: .schemaText(15), color: NSColor(SchemaTheme.inkMuted), lineHeight: 24, isItalic: true)
        case .todo:
            BlockTextStyle(
                font: .schemaText(15),
                color: NSColor(block.isChecked ? SchemaTheme.inkMuted : SchemaTheme.ink),
                lineHeight: 24,
                isStruckThrough: block.isChecked
            )
        case .text, .bullet, .divider:
            BlockTextStyle(font: .schemaText(15), color: NSColor(SchemaTheme.ink), lineHeight: 24)
        }
    }

    private var accessibilityName: String {
        switch block.kind {
        case .heading: "Heading"
        case .bullet: "Bullet"
        case .todo: block.isChecked ? "To-do, done" : "To-do"
        case .quote: "Quote"
        case .text, .divider: "Text"
        }
    }
}

extension BlockKind {
    var menuTitle: String {
        switch self {
        case .text: "Text"
        case .heading: "Heading"
        case .bullet: "Bullet list"
        case .todo: "To-do"
        case .quote: "Quote"
        case .divider: "Divider"
        }
    }
}

extension NSFont {
    /// Satoshi, the text face.
    static func schemaText(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        schemaFont(family: SchemaFont.textFamily, size: size, weight: weight)
    }

    /// Space Grotesk, the display face.
    static func schemaDisplay(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        schemaFont(family: SchemaFont.displayFamily, size: size, weight: weight)
    }

    private static func schemaFont(family: String, size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            .traits: [NSFontDescriptor.TraitKey.weight: weight],
        ])
        return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

//
//  BlockEditor.swift
//  Schema
//
//  Editing operations on an ordered list of blocks: a scratchpad page now
//  (#38), a task's body later (#31). The views only report what happened
//  (Return at an offset, Backspace at the start, an arrow off the edge);
//  this decides what changes and which block gets the caret next.
//

import Foundation
import Observation
import SwiftData

/// Where the caret goes in a block.
enum CaretPlacement: Equatable {
    case start
    case end
    /// UTF-16 offset, as NSTextView counts.
    case offset(Int)
    /// Select all the text, e.g. to rename a page title.
    case all
}

/// A request to move the caret. `token` changes on every request, so asking
/// for the same block twice still moves the caret.
struct BlockFocusRequest: Equatable {
    let blockID: UUID
    let caret: CaretPlacement
    let token = UUID()
}

@MainActor
@Observable
final class BlockEditor {
    enum Owner {
        case page(SchemaList)
        case task(SchemaTask)
    }

    let owner: Owner
    private let context: ModelContext

    /// The latest caret request; block views apply it once.
    private(set) var focusRequest: BlockFocusRequest?
    /// The block whose text view has the keyboard, for the gutter highlight.
    var activeBlockID: UUID?
    /// Esc in a line with no menu open (the task page uses it to go back).
    @ObservationIgnored var onEscape: (() -> Void)?

    init(owner: Owner, context: ModelContext) {
        self.owner = owner
        self.context = context
    }

    /// The blocks in display order. Sorting a long page on every read was
    /// a large part of each keystroke (#45), so the order is kept until a
    /// block is added or removed. Reading the relationship still lets
    /// SwiftUI track changes to it.
    var blocks: [SchemaBlock] {
        let unordered: [SchemaBlock] = switch owner {
        case .page(let page): page.blocks
        case .task(let task): task.blocks
        }
        if let cachedOrder, cachedOrder.count == unordered.count {
            return cachedOrder
        }
        let ordered = unordered.inDisplayOrder
        cachedOrder = ordered
        return ordered
    }

    @ObservationIgnored private var cachedOrder: [SchemaBlock]?

    // MARK: Focus

    func focus(_ block: SchemaBlock, caret: CaretPlacement) {
        focusRequest = BlockFocusRequest(blockID: block.id, caret: caret)
    }

    func focusPrevious(of block: SchemaBlock) {
        guard let previous = textBlock(before: block) else { return }
        focus(previous, caret: .end)
    }

    func focusNext(of block: SchemaBlock) {
        guard let next = textBlock(after: block) else { return }
        focus(next, caret: .start)
    }

    /// Caret on the first line, adding one if the body is empty.
    func focusFirstLine() {
        if let first = blocks.first(where: { $0.kind.holdsText }) {
            focus(first, caret: .end)
        } else {
            focusEnd()
        }
    }

    /// Click in the empty space below the last block: focus the last block
    /// if it is empty text, otherwise add an empty text block.
    func focusEnd() {
        if let last = blocks.last, last.kind == .text, last.text.isEmpty {
            focus(last, caret: .end)
        } else {
            let block = insertBlock(after: blocks.last, kind: .text)
            focus(block, caret: .start)
        }
    }

    // MARK: Editing

    func setText(_ text: String, of block: SchemaBlock) {
        guard block.text != text else { return }
        block.text = text
        block.updatedAt = .now
    }

    /// Text typed by the person (not set by the editor itself): applies
    /// markdown shortcuts and keeps the / menu in step.
    func userTyped(_ text: String, in block: SchemaBlock) {
        setText(text, of: block)
        if applyMarkdownShortcut(to: block) { return }
        updateSlashMenu(for: block)
    }

    // MARK: Markdown shortcuts

    /// Prefixes that turn a text line into another kind as you type them
    /// at its start. `---` alone makes a divider.
    static let markdownPrefixes: [(prefix: String, kind: BlockKind)] = [
        ("### ", .heading), ("## ", .heading), ("# ", .heading),
        ("- ", .bullet), ("* ", .bullet),
        ("[ ] ", .todo), ("[] ", .todo),
        ("> ", .quote),
    ]

    @discardableResult
    private func applyMarkdownShortcut(to block: SchemaBlock) -> Bool {
        guard block.kind == .text else { return false }
        if block.text == "---" {
            makeDivider(block)
            return true
        }
        for (prefix, kind) in Self.markdownPrefixes where block.text.hasPrefix(prefix) {
            let rest = String(block.text.dropFirst(prefix.count))
            block.kind = kind
            setText(rest, of: block)
            slashMenu = nil
            save()
            focus(block, caret: .start)
            return true
        }
        return false
    }

    /// Turns `block` into a divider and puts the caret on a new line below.
    private func makeDivider(_ block: SchemaBlock) {
        block.kind = .divider
        slashMenu = nil
        let next = insertBlock(after: block, kind: .text)
        save()
        focus(next, caret: .start)
    }

    // MARK: Slash menu

    struct SlashMenu: Equatable {
        enum Mode: Equatable {
            /// Opened by typing / at the start of a line; the typed text filters it.
            case insert
            /// Opened with ⌘/ to change the line's kind; leaves the text alone.
            case turnInto
        }

        let blockID: UUID
        let mode: Mode
        var query: String = ""
        var selection: Int = 0
    }

    private(set) var slashMenu: SlashMenu?
    /// Text the menu was closed on with Esc, so it stays closed until the line changes.
    private var dismissedSlashText: (blockID: UUID, text: String)?

    static let menuAliases: [BlockKind: [String]] = [
        .text: ["text", "paragraph", "plain"],
        .heading: ["heading", "title", "h1", "h2", "h3", "#"],
        .bullet: ["bullet list", "list", "ul", "-"],
        .todo: ["to-do", "todo", "task", "check", "checkbox", "[]"],
        .quote: ["quote", "blockquote", ">"],
        .divider: ["divider", "line", "separator", "hr", "---"],
    ]

    /// Kinds the open menu offers, filtered by what was typed after /.
    var menuItems: [BlockKind] {
        guard let menu = slashMenu else { return [] }
        let query = menu.query.lowercased()
        guard !query.isEmpty else { return BlockKind.allCases }
        return BlockKind.allCases.filter { kind in
            kind.menuTitle.lowercased().contains(query)
                || (Self.menuAliases[kind] ?? []).contains { $0.hasPrefix(query) }
        }
    }

    /// The menu is open on this block and has something to choose.
    func isMenuOpen(on block: SchemaBlock) -> Bool {
        slashMenu?.blockID == block.id && !menuItems.isEmpty
    }

    private func updateSlashMenu(for block: SchemaBlock) {
        if let dismissed = dismissedSlashText, dismissed.blockID == block.id {
            if dismissed.text == block.text { return }
            dismissedSlashText = nil
        }
        if slashMenu?.mode == .turnInto {
            // Typing closes the ⌘/ menu.
            slashMenu = nil
            return
        }
        guard block.kind.holdsText, block.text.hasPrefix("/") else {
            if slashMenu?.blockID == block.id { slashMenu = nil }
            return
        }
        let query = String(block.text.dropFirst())
        guard !query.contains(" "), !query.contains("\n"), query.count <= 24 else {
            slashMenu = nil
            return
        }
        var menu = slashMenu?.blockID == block.id ? slashMenu! : SlashMenu(blockID: block.id, mode: .insert)
        if menu.query != query { menu.selection = 0 }
        menu.query = query
        slashMenu = menu
    }

    /// ⌘/ on a line: choose a kind for it without typing.
    func openTurnInto(for block: SchemaBlock) {
        guard block.kind.holdsText else { return }
        let current = BlockKind.allCases.firstIndex(of: block.kind) ?? 0
        slashMenu = SlashMenu(blockID: block.id, mode: .turnInto, selection: current)
    }

    func moveMenuSelection(by delta: Int) {
        guard var menu = slashMenu else { return }
        let count = menuItems.count
        guard count > 0 else { return }
        menu.selection = (menu.selection + delta + count) % count
        slashMenu = menu
    }

    func selectMenuItem(at index: Int) {
        guard var menu = slashMenu, menuItems.indices.contains(index) else { return }
        menu.selection = index
        slashMenu = menu
    }

    /// Applies the selected kind (or `kind`) to the line the menu is on.
    func chooseMenuItem(_ kind: BlockKind? = nil, in block: SchemaBlock) {
        guard let menu = slashMenu, menu.blockID == block.id else { return }
        let items = menuItems
        guard let chosen = kind ?? (items.indices.contains(menu.selection) ? items[menu.selection] : nil) else { return }
        slashMenu = nil
        if menu.mode == .insert {
            // Remove "/query" from the start of the line.
            setText(String(block.text.dropFirst(1 + menu.query.count)), of: block)
        }
        if chosen == .divider {
            makeDivider(block)
            return
        }
        block.kind = chosen
        save()
        focus(block, caret: menu.mode == .insert ? .start : .end)
    }

    /// Esc: closes the menu and leaves the typed text as it is.
    func dismissMenu() {
        guard let menu = slashMenu else { return }
        if menu.mode == .insert, let block = blocks.first(where: { $0.id == menu.blockID }) {
            dismissedSlashText = (block.id, block.text)
        }
        slashMenu = nil
    }

    /// Return at `offset` (UTF-16). Splits the block: the text after the
    /// caret moves into a new block below, which gets the caret.
    func splitBlock(_ block: SchemaBlock, at offset: Int) {
        let text = block.text as NSString
        let offset = min(max(offset, 0), text.length)

        // Return on an empty bullet or to-do ends the list.
        if [.bullet, .todo].contains(block.kind), text.length == 0 {
            block.kind = .text
            save()
            focus(block, caret: .start)
            return
        }

        // Return at the start of a line with text: open an empty line above
        // and keep the caret where it is.
        if offset == 0, text.length > 0 {
            insertBlock(before: block, kind: continuingKind(of: block))
            save()
            focus(block, caret: .start)
            return
        }

        let head = text.substring(to: offset)
        let tail = text.substring(from: offset)
        setText(head, of: block)
        let next = insertBlock(after: block, kind: continuingKind(of: block), text: tail)
        save()
        focus(next, caret: .start)
    }

    /// Backspace with the caret at the start of `block`.
    func backspaceAtStart(of block: SchemaBlock) {
        // A heading, bullet, to-do or quote first turns back into text.
        if block.kind != .text, block.kind != .divider {
            block.kind = .text
            save()
            focus(block, caret: .start)
            return
        }
        guard let previous = previousBlock(of: block) else { return }

        if previous.kind == .divider {
            delete(previous)
            save()
            focus(block, caret: .start)
            return
        }

        let joinAt = (previous.text as NSString).length
        setText(previous.text + block.text, of: previous)
        delete(block)
        save()
        focus(previous, caret: .offset(joinAt))
    }

    func setKind(_ kind: BlockKind, of block: SchemaBlock) {
        block.kind = kind
        save()
        if kind.holdsText {
            focus(block, caret: .end)
        }
    }

    func toggleChecked(_ block: SchemaBlock) {
        guard block.kind.isCheckable else { return }
        block.isChecked.toggle()
        block.updatedAt = .now
        save()
    }

    /// Adds an empty text block right below `block` and focuses it.
    func addBlock(below block: SchemaBlock) {
        let new = insertBlock(after: block, kind: .text)
        save()
        focus(new, caret: .start)
    }

    func remove(_ block: SchemaBlock) {
        let neighbour = textBlock(before: block) ?? textBlock(after: block)
        delete(block)
        save()
        if let neighbour { focus(neighbour, caret: .end) }
    }

    // MARK: Ordering

    /// Inserts right after `anchor`; with no anchor, at the top.
    @discardableResult
    func insertBlock(after anchor: SchemaBlock?, kind: BlockKind, text: String = "") -> SchemaBlock {
        let ordered = blocks
        guard let anchor, let index = ordered.firstIndex(where: { $0.id == anchor.id }) else {
            return insert(kind: kind, text: text, between: nil, and: ordered.first)
        }
        let next = index + 1 < ordered.count ? ordered[index + 1] : nil
        return insert(kind: kind, text: text, between: anchor, and: next)
    }

    @discardableResult
    func insertBlock(before anchor: SchemaBlock, kind: BlockKind, text: String = "") -> SchemaBlock {
        let ordered = blocks
        guard let index = ordered.firstIndex(where: { $0.id == anchor.id }) else {
            return insertBlock(after: ordered.last, kind: kind, text: text)
        }
        return insert(kind: kind, text: text, between: index > 0 ? ordered[index - 1] : nil, and: anchor)
    }

    private func insert(kind: BlockKind, text: String, between before: SchemaBlock?, and after: SchemaBlock?) -> SchemaBlock {
        if let before, let after, BlockOrdering.needsRenumbering(between: before.sortIndex, and: after.sortIndex) {
            renumber()
        }
        let index = BlockOrdering.index(between: before?.sortIndex, and: after?.sortIndex)
        let block: SchemaBlock
        switch owner {
        case .page(let page): block = SchemaBlock(kind: kind, text: text, sortIndex: index, page: page)
        case .task(let task): block = SchemaBlock(kind: kind, text: text, sortIndex: index, task: task)
        }
        context.insert(block)
        cachedOrder = nil
        return block
    }

    private func renumber() {
        let ordered = blocks
        for (block, index) in zip(ordered, BlockOrdering.renumbered(count: ordered.count)) {
            block.sortIndex = index
        }
    }

    // MARK: Helpers

    /// Bullets and to-dos continue on the next line; everything else is text.
    private func continuingKind(of block: SchemaBlock) -> BlockKind {
        [.bullet, .todo].contains(block.kind) ? block.kind : .text
    }

    private func previousBlock(of block: SchemaBlock) -> SchemaBlock? {
        let ordered = blocks
        guard let index = ordered.firstIndex(where: { $0.id == block.id }), index > 0 else { return nil }
        return ordered[index - 1]
    }

    private func textBlock(before block: SchemaBlock) -> SchemaBlock? {
        let ordered = blocks
        guard let index = ordered.firstIndex(where: { $0.id == block.id }) else { return nil }
        return ordered[..<index].last { $0.kind.holdsText }
    }

    private func textBlock(after block: SchemaBlock) -> SchemaBlock? {
        let ordered = blocks
        guard let index = ordered.firstIndex(where: { $0.id == block.id }) else { return nil }
        return ordered[(index + 1)...].first { $0.kind.holdsText }
    }

    private func delete(_ block: SchemaBlock) {
        block.page = nil
        block.task = nil
        context.delete(block)
        cachedOrder = nil
    }

    private func save() {
        try? context.save()
    }

    /// For extensions in other files.
    func saveChanges() { save() }
}

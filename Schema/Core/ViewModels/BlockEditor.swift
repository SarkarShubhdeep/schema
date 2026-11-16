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

    init(owner: Owner, context: ModelContext) {
        self.owner = owner
        self.context = context
    }

    var blocks: [SchemaBlock] {
        switch owner {
        case .page(let page): page.orderedBlocks
        case .task(let task): task.orderedBlocks
        }
    }

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
    }

    private func save() {
        try? context.save()
    }
}

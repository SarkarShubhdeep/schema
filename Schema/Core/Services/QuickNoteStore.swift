//
//  QuickNoteStore.swift
//  Schema
//
//  Where Quick note (⌃⌥N, #41) saves. A note goes to the top of one chosen
//  scratchpad (Ideas by default) under a heading with today's date, newest
//  first. Each line of the note becomes a block; markdown prefixes such as
//  "- " or "[] " work as they do in the editor. ⌘Return saves the note as
//  a task instead.
//

import Foundation
import SwiftData

@MainActor
enum QuickNoteStore {
    static let defaultPageTitle = "Ideas"

    /// The scratchpad notes go to: the preferred one, else the first
    /// scratchpad, else none (`save` then creates Ideas).
    static func targetPage(in lists: [SchemaList], preferredID: UUID?) -> SchemaList? {
        let scratchpads = lists.filter(\.isScratchpad).sorted { $0.order < $1.order }
        if let preferredID, let preferred = scratchpads.first(where: { $0.id == preferredID }) {
            return preferred
        }
        return scratchpads.first
    }

    /// The heading notes are filed under, e.g. "Monday, 16 November".
    static func dateHeading(for date: Date, calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide)
        style.calendar = calendar
        return date.formatted(style)
    }

    /// Saves `text` at the top of the target page. Returns the page, or nil
    /// when the note is empty.
    @discardableResult
    static func saveNote(
        _ text: String,
        lists: [SchemaList],
        preferredPageID: UUID?,
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SchemaList? {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let page = targetPage(in: lists, preferredID: preferredPageID) ?? makeDefaultPage(lists: lists, context: context)
        let blocks = page.orderedBlocks
        let heading = dateHeading(for: now, calendar: calendar)

        // Today's heading stays at the top; new notes go right under it, so
        // the newest note is first.
        var anchor: SchemaBlock
        var next: SchemaBlock?
        if let first = blocks.first, first.kind == .heading, first.text == heading {
            anchor = first
            next = blocks.dropFirst().first
        } else {
            let index = BlockOrdering.index(between: nil, and: blocks.first?.sortIndex)
            anchor = SchemaBlock(kind: .heading, text: heading, sortIndex: index, page: page)
            context.insert(anchor)
            next = blocks.first
        }

        for line in lines {
            let (kind, body) = parse(line)
            var before = anchor.sortIndex
            if let next, BlockOrdering.needsRenumbering(between: before, and: next.sortIndex) {
                renumber(page)
                before = anchor.sortIndex
            }
            let index = BlockOrdering.index(between: before, and: next?.sortIndex)
            let block = SchemaBlock(kind: kind, text: body, sortIndex: index, page: page)
            context.insert(block)
            anchor = block
        }
        try? context.save()
        return page
    }

    /// ⌘Return: the note becomes one task in the default to-do list.
    @discardableResult
    static func saveTask(
        _ text: String,
        lists: [SchemaList],
        allTasks: [SchemaTask],
        defaultPageID: UUID?,
        context: ModelContext
    ) -> SchemaTask? {
        let title = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !title.isEmpty else { return nil }
        let pages = lists.filter(\.acceptsTasks).sorted { $0.order < $1.order }
        guard let page = pages.first(where: { $0.id == defaultPageID }) ?? pages.first else { return nil }
        let task = SchemaTask(title: title, list: page)
        task.manualSortIndex = (allTasks.filter { $0.list?.id == page.id }.map(\.manualSortIndex).max() ?? 0) + 1
        context.insert(task)
        try? context.save()
        return task
    }

    // MARK: Helpers

    private static func parse(_ line: String) -> (BlockKind, String) {
        if line == "---" { return (.divider, "") }
        for (prefix, kind) in BlockEditor.markdownPrefixes where line.hasPrefix(prefix) {
            return (kind, String(line.dropFirst(prefix.count)))
        }
        return (.text, line)
    }

    private static func makeDefaultPage(lists: [SchemaList], context: ModelContext) -> SchemaList {
        let order = (lists.map(\.order).max() ?? 0) + 1
        let page = SchemaList(title: defaultPageTitle, order: order, kind: .scratchpad)
        context.insert(page)
        return page
    }

    private static func renumber(_ page: SchemaList) {
        let ordered = page.orderedBlocks
        for (block, index) in zip(ordered, BlockOrdering.renumbered(count: ordered.count)) {
            block.sortIndex = index
        }
    }
}

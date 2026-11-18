//
//  QuickNoteStore.swift
//  Schema
//
//  Where Quick note (⌃⌥N, #41) saves. A note goes to the top of one chosen
//  scratchpad (Ideas by default) under a heading with today's date, newest
//  first. Each line of the note becomes a line of the page's document (#77); markdown prefixes such as
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
        // Today's heading stays at the top; new notes go right under it, so
        // the newest note is first.
        let note = lines.map { line -> TipTapDocument.Line in
            let (kind, body) = parse(line)
            return TipTapDocument.Line(kind: kind, text: body)
        }
        page.setDocument(PageDocument.prependingNote(note, under: dateHeading(for: now, calendar: calendar), to: page.documentJSON), editedAt: now)
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
}

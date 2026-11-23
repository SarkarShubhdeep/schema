//
//  TagPages.swift
//  Schema
//
//  Tag pages (#102) in the store: making one for each new #tag, gathering
//  a tag's lines from every page, task body and task title, ticking them
//  from the tag page, and keeping chips and titles in step when a tag page
//  is renamed or deleted. PageTags does the work on JSON; this finds the
//  pages and tasks to apply it to.
//

import Foundation
import SwiftData

@MainActor
enum TagPages {
    /// Posted after a page or task body is saved, so an open tag page can
    /// gather its lines again.
    static let documentSaved = Notification.Name("SchemaDocumentSaved")

    /// What a tag page shows below its own writing (tagged.js).
    struct Lines: Encodable, Equatable {
        var hideDone: Bool
        var groups: [Group]

        var json: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        }

        var openCount: Int { groups.reduce(0) { $0 + $1.lines.count { $0.kind == .todo && !$0.checked } } }
    }

    struct Group: Encodable, Equatable {
        var title: String
        /// The page or task to open with Open.
        var holderId: String
        /// Open opens a task's page rather than a page.
        var isTask: Bool
        var lines: [Line]
    }

    struct Line: Encodable, Equatable {
        var holderId: String
        var path: [Int]?
        var kind: PageTags.LineKind
        var text: String
        var otherTags: [String]
        var checked: Bool
        var linkedPage: String?
        /// A task on a to-do list, tagged in its title.
        var isTask: Bool
    }

    // MARK: Making tag pages

    /// Makes a tag page for each tag in `json` that has none yet, named as
    /// the chip says. Returns whether any was made.
    @discardableResult
    static func ensurePages(for json: String, in context: ModelContext) -> Bool {
        let tags = PageTags.tags(in: json)
        guard !tags.isEmpty, let lists = try? context.fetch(FetchDescriptor<SchemaList>()) else { return false }
        let ids = Set(lists.map(\.id))
        var order = (lists.map(\.order).max() ?? -1) + 1
        var made = false
        for tag in tags where !ids.contains(tag.id) {
            guard let name = PageTags.name(tag.label) else { continue }
            let page = SchemaList(title: name, order: order, kind: .tag)
            page.id = tag.id
            context.insert(page)
            order += 1
            made = true
        }
        return made
    }

    // MARK: A tag's lines

    static func lines(for tag: SchemaList, hideDone: Bool, in context: ModelContext) -> Lines {
        let lists = ((try? context.fetch(FetchDescriptor<SchemaList>())) ?? []).sorted { $0.order < $1.order }
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
        let taskByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var groups: [Group] = []

        func docLines(_ holder: any PageDocumentHolder, id: UUID) -> [Line] {
            guard holder.hasDocument else { return [] }
            return PageTags.lines(taggedWith: tag.id, in: holder.documentJSON).map { line in
                Line(
                    holderId: id.uuidString, path: line.path, kind: line.kind, text: line.text,
                    otherTags: line.otherTags, checked: line.taskID.flatMap { taskByID[$0]?.isCompleted } ?? line.isChecked,
                    linkedPage: line.taskID.flatMap { taskByID[$0]?.list?.title }, isTask: false
                )
            }
        }

        for list in lists where list.id != tag.id && !list.isEverythingList {
            var lines = docLines(list, id: list.id)
            // Tasks on this to-do list tagged in their title.
            for task in tasks where task.list?.id == list.id && PageTags.title(task.title, hasTag: tag.title) {
                lines.append(Line(
                    holderId: task.id.uuidString, path: nil, kind: .todo,
                    text: PageTags.strippingTag(from: task.title, named: tag.title),
                    otherTags: [], checked: task.isCompleted, linkedPage: nil, isTask: true
                ))
            }
            if !lines.isEmpty {
                groups.append(Group(title: list.title, holderId: list.id.uuidString, isTask: false, lines: lines))
            }
        }
        // Task pages' bodies.
        for task in tasks.sorted(by: { $0.createdAt < $1.createdAt }) {
            let lines = docLines(task, id: task.id)
            if !lines.isEmpty {
                groups.append(Group(title: task.title, holderId: task.id.uuidString, isTask: true, lines: lines))
            }
        }
        return Lines(hideDone: hideDone, groups: groups)
    }

    // MARK: Ticking from the tag page

    /// Ticks a tagged line where it lives: a to-do in a page or task body
    /// (and its linked task), or a task tagged in its title.
    static func toggle(holderID: UUID, path: [Int], isTask: Bool, checked: Bool, in context: ModelContext, toggleTask: (SchemaTask) -> Void) {
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
        if isTask, path.isEmpty {
            if let task = tasks.first(where: { $0.id == holderID }), task.isCompleted != checked { toggleTask(task) }
            return
        }
        let holder: (any PageDocumentHolder)? = (try? context.fetch(FetchDescriptor<SchemaList>()))?.first { $0.id == holderID }
            ?? tasks.first { $0.id == holderID }
        guard let holder, let json = PageTags.settingChecked(checked, at: path, in: holder.documentJSON) else { return }
        holder.setDocument(json)
        for id in PageDocument.tasksToToggle(in: json, isDone: { id in tasks.first { $0.id == id }?.isCompleted }) {
            if let task = tasks.first(where: { $0.id == id }) { toggleTask(task) }
        }
        try? context.save()
    }

    // MARK: Renaming and deleting

    /// Renames a tag page, its chips everywhere, and "#old" in task titles.
    static func rename(_ tag: SchemaList, to raw: String, in context: ModelContext) {
        guard let name = PageTags.name(raw), name != tag.title else { return }
        let old = tag.title
        tag.title = name
        for holder in holders(in: context) {
            if let json = PageTags.relabeling(tag.id, to: name, in: holder.documentJSON) { holder.setDocument(json) }
        }
        for task in (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? [] where PageTags.title(task.title, hasTag: old) {
            task.title = PageTags.renamingTag(in: task.title, from: old, to: name)
        }
        try? context.save()
    }

    /// Before a tag page is deleted: its chips become plain words, and
    /// "#name" in task titles loses its #.
    static func removeEverywhere(_ tag: SchemaList, in context: ModelContext) {
        for holder in holders(in: context) {
            if let json = PageTags.removing(tag.id, in: holder.documentJSON) { holder.setDocument(json) }
        }
        for task in (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? [] where PageTags.title(task.title, hasTag: tag.title) {
            task.title = PageTags.removingTag(from: task.title, named: tag.title)
        }
    }

    private static func holders(in context: ModelContext) -> [any PageDocumentHolder] {
        let lists: [any PageDocumentHolder] = ((try? context.fetch(FetchDescriptor<SchemaList>())) ?? []).filter(\.hasDocument)
        let tasks: [any PageDocumentHolder] = ((try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []).filter(\.hasDocument)
        return lists + tasks
    }
}

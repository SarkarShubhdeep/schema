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

    /// A tag page's synced blocks (#113), as the editor takes them
    /// (synced.js): every block tagged with it elsewhere, live.
    struct Synced: Equatable {
        var json: String
        var openCount: Int
        var pageCount: Int
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

    // MARK: A tag's synced blocks

    /// Every block tagged with `tag` on other pages and in task bodies, and
    /// every task tagged in its title, in page order. Blocks without a
    /// lasting id get one where they live first.
    static func synced(for tag: SchemaList, hideDone: Bool, grouped: Bool, in context: ModelContext) -> Synced {
        let lists = ((try? context.fetch(FetchDescriptor<SchemaList>())) ?? []).sorted { $0.order < $1.order }
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
        let taskByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var blocks: [[String: Any]] = []
        var open = 0
        var pages = Set<String>()

        func add(_ holder: any PageDocumentHolder, id: UUID, source: String) {
            guard holder.hasDocument, holder.documentJSON.contains(tag.id.uuidString) else { return }
            if let withIDs = PageTags.ensuringBlockIDs(in: holder.documentJSON) { holder.setDocument(withIDs) }
            for line in PageTags.lines(taggedWith: tag.id, in: holder.documentJSON) {
                guard let bid = line.blockID else { continue }
                let checked = line.taskID.flatMap { taskByID[$0]?.isCompleted } ?? line.isChecked
                if line.kind == .todo, !checked { open += 1 }
                pages.insert(id.uuidString)
                var block: [String: Any] = [
                    "holderId": id.uuidString, "bid": bid, "kind": line.kind.rawValue,
                    "checked": checked, "source": source, "content": line.inline,
                ]
                if let page = line.taskID.flatMap({ taskByID[$0]?.list?.title }) { block["linkedPage"] = page }
                if let number = line.number { block["number"] = number }
                blocks.append(block)
            }
        }

        // Tag pages are pages too: a line made on #chores and tagged #idea
        // shows on #idea from #chores.
        for list in lists where list.id != tag.id && !list.isEverythingList {
            add(list, id: list.id, source: list.isTagPage ? "#\(list.title)" : list.title)
            for task in tasks where task.list?.id == list.id && PageTags.title(task.title, hasTag: tag.title) {
                if !task.isCompleted { open += 1 }
                pages.insert(list.id.uuidString)
                blocks.append([
                    "holderId": task.id.uuidString, "bid": "task:\(task.id.uuidString)", "kind": "task",
                    "checked": task.isCompleted, "source": list.title,
                    "content": [["type": "text", "text": task.title]],
                ])
            }
        }
        for task in tasks.sorted(by: { $0.createdAt < $1.createdAt }) {
            add(task, id: task.id, source: task.title)
        }
        let payload: [String: Any] = ["grouped": grouped, "hideDone": hideDone, "tagLabel": tag.title, "blocks": blocks]
        let json = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        return Synced(json: json, openCount: open, pageCount: pages.count)
    }

    // MARK: Writing back

    /// The tag page was edited: each synced block's line and tick go back to
    /// the block where it lives, and blocks made with Return there are added
    /// after the block they came from.
    static func writeBack(_ json: String, in context: ModelContext, toggleTask: (SchemaTask) -> Void) {
        guard json.contains(PageTags.syncedBlockType), let doc = PageDocument.parse(json) else { return }
        let lists = (try? context.fetch(FetchDescriptor<SchemaList>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
        var touched: [ObjectIdentifier: any PageDocumentHolder] = [:]
        for node in doc["content"] as? [[String: Any]] ?? [] where node["type"] as? String == PageTags.syncedBlockType {
            let attrs = node["attrs"] as? [String: Any] ?? [:]
            guard let holderString = attrs["holderId"] as? String, let holderID = UUID(uuidString: holderString),
                  let bid = attrs["bid"] as? String else { continue }
            let kind = attrs["kind"] as? String ?? "paragraph"
            let checked = attrs["checked"] as? Bool ?? false
            let after = attrs["after"] as? String
            let inline = ((node["content"] as? [[String: Any]])?.first?["content"] as? [[String: Any]]) ?? []

            if kind == "task" {
                let title = PageDocument.plainText(["type": "doc", "content": [["type": "paragraph", "content": inline]]])
                    .trimmingCharacters(in: .whitespaces)
                if let task = tasks.first(where: { $0.id == holderID }) {
                    if !title.isEmpty, task.title != title { task.title = title }
                    if task.isCompleted != checked { toggleTask(task) }
                } else if bid.hasPrefix("task:"), let newID = UUID(uuidString: String(bid.dropFirst(5))),
                          let after, let previous = tasks.first(where: { "task:\($0.id.uuidString)" == after }),
                          !title.isEmpty, !tasks.contains(where: { $0.id == newID }) {
                    let task = SchemaTask(title: title, list: previous.list)
                    task.id = newID
                    task.manualSortIndex = previous.manualSortIndex + 0.5
                    context.insert(task)
                }
                continue
            }
            let holder: (any PageDocumentHolder)? = lists.first { $0.id == holderID } ?? tasks.first { $0.id == holderID }
            guard let holder else { continue }
            let source = holder.documentJSON
            var next = PageTags.updating(block: bid, inline: inline, checked: kind == "todo" ? checked : nil, in: source)
            if next == nil, PageTags.path(ofBlock: bid, in: source) == nil, let after {
                next = PageTags.inserting(after: after, kind: PageTags.LineKind(rawValue: kind) ?? .paragraph, blockID: bid, inline: inline, in: source)
            }
            guard let next else { continue }
            holder.setDocument(next)
            touched[ObjectIdentifier(holder)] = holder
            for id in PageDocument.tasksToToggle(in: next, isDone: { id in tasks.first { $0.id == id }?.isCompleted }) {
                if let task = tasks.first(where: { $0.id == id }) { toggleTask(task) }
            }
        }
        try? context.save()
    }

    /// Synced blocks taken off a tag page by hand: the tag comes off each
    /// where it lives (a task loses "#tag" from its title).
    static func removeTag(_ tag: SchemaList, from items: [(holderID: UUID, blockID: String, kind: String)], in context: ModelContext) {
        let lists = (try? context.fetch(FetchDescriptor<SchemaList>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
        for item in items {
            if item.kind == "task" {
                if let task = tasks.first(where: { $0.id == item.holderID }) {
                    task.title = PageTags.strippingTag(from: task.title, named: tag.title)
                }
                continue
            }
            let holder: (any PageDocumentHolder)? = lists.first { $0.id == item.holderID } ?? tasks.first { $0.id == item.holderID }
            if let holder, let json = PageTags.removing(tag.id, fromBlock: item.blockID, in: holder.documentJSON) {
                holder.setDocument(json)
            }
        }
        try? context.save()
    }

    /// Delete everywhere: the block goes from where it lives, and so from
    /// every tag page. A task tagged in its title is deleted.
    static func deleteEverywhere(holderID: UUID, blockID: String, kind: String, in context: ModelContext) {
        let lists = (try? context.fetch(FetchDescriptor<SchemaList>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
        if kind == "task" {
            if let task = tasks.first(where: { $0.id == holderID }) { context.delete(task) }
        } else {
            let holder: (any PageDocumentHolder)? = lists.first { $0.id == holderID } ?? tasks.first { $0.id == holderID }
            if let holder, let json = PageTags.deleting(block: blockID, in: holder.documentJSON) { holder.setDocument(json) }
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

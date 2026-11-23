//
//  PageTags.swift
//  Schema
//
//  #tags (#102). A tag in a document is a mention chip of kind "tag" whose
//  id is its tag page's id and whose label is the tag's name without the #.
//  A tag page gathers every line tagged with it, live: these functions find
//  those lines, tick them, and keep chips in step when a tag page is renamed
//  or deleted. In task titles on to-do lists a tag is plain text, "#chores".
//  Pure functions on JSON and strings, so they are easy to test.
//

import Foundation

nonisolated enum PageTags {
    typealias Node = TipTapDocument.Node

    static let mentionKind = "tag"
    /// The lasting id every block carries (#113), so a synced block can be
    /// found where it lives after its page changes.
    static let blockIDAttribute = "bid"
    /// A tag page's synced block (#113): the tag page's copy of where it is
    /// shown, never read as a tagged line of the tag page itself.
    static let syncedBlockType = "syncedBlock"

    struct Tag: Equatable {
        var id: UUID
        var label: String
    }

    /// What kind of block a tagged line is, so the tag page draws it the same way.
    enum LineKind: String, Codable, Equatable {
        case todo, paragraph, bullet, numbered, heading, quote
    }

    /// A line carrying a tag. `path` leads from the document to the block:
    /// the to-do or list item, or the paragraph or heading itself.
    struct Line: Equatable {
        var path: [Int]
        var kind: LineKind
        /// The line's text without this tag.
        var text: String
        /// Its other tags, by name.
        var otherTags: [String]
        var isChecked: Bool
        var taskID: UUID?
        /// The block's lasting id (#113), when it has one.
        var blockID: String?
        /// The line's own inline content (text, chips), as TipTap JSON.
        var inline: [Node] = []
        /// A numbered item's number.
        var number: Int?

        static func == (a: Line, b: Line) -> Bool {
            a.path == b.path && a.kind == b.kind && a.text == b.text && a.otherTags == b.otherTags
                && a.isChecked == b.isChecked && a.taskID == b.taskID && a.blockID == b.blockID && a.number == b.number
        }
    }

    // MARK: Names

    /// A tag name as typed after the #: starts with a letter, then letters,
    /// digits, - _ or /. Returns nil for anything else.
    static func name(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let first = trimmed.unicodeScalars.first, CharacterSet.letters.contains(first) else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_/"))
        guard trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return trimmed
    }

    // MARK: Reading

    /// Every tag in a document, once each, in order.
    static func tags(in json: String) -> [Tag] {
        guard json.contains("\"\(mentionKind)\""), let doc = PageDocument.parse(json) else { return [] }
        var seen = Set<UUID>()
        var result: [Tag] = []
        walk(doc) { node in
            guard let tag = tag(of: node), seen.insert(tag.id).inserted else { return }
            result.append(tag)
        }
        return result
    }

    /// The lines tagged with `tagID`, in document order.
    static func lines(taggedWith tagID: UUID, in json: String) -> [Line] {
        guard json.contains(tagID.uuidString), let doc = PageDocument.parse(json) else { return [] }
        var result: [Line] = []
        collect(doc, path: [], parent: nil, grandparent: nil, tagID: tagID, into: &result)
        return result
    }

    private static func collect(_ node: Node, path: [Int], parent: Node?, grandparent: Node?, tagID: UUID, into result: inout [Line]) {
        let type = node["type"] as? String
        if type == syncedBlockType { return }
        if type == "paragraph" || type == "heading" {
            let inline = children(of: node)
            guard inline.contains(where: { tag(of: $0)?.id == tagID }) else { return }
            let parentType = parent?["type"] as? String
            let isFirstChild = path.last == 0
            var line = Line(path: path, kind: type == "heading" ? .heading : .paragraph, text: "", otherTags: [], isChecked: false)
            line.blockID = blockID(of: node)
            line.inline = inline
            if let parent, isFirstChild, parentType == "taskItem" {
                let attrs = parent["attrs"] as? [String: Any] ?? [:]
                line.kind = .todo
                line.path = Array(path.dropLast())
                line.isChecked = attrs["checked"] as? Bool ?? false
                line.taskID = (attrs[PageDocument.taskIDAttribute] as? String).flatMap(UUID.init(uuidString:))
                line.blockID = blockID(of: parent)
            } else if let parent, isFirstChild, parentType == "listItem" {
                let ordered = (grandparent?["type"] as? String) == "orderedList"
                line.kind = ordered ? .numbered : .bullet
                line.path = Array(path.dropLast())
                line.blockID = blockID(of: parent)
                if ordered {
                    let start = ((grandparent?["attrs"] as? [String: Any])?["start"] as? Int) ?? 1
                    line.number = start + (path.dropLast().last ?? 0)
                }
            } else if parentType == "blockquote" {
                line.kind = .quote
            }
            var words: [String] = []
            for child in inline {
                if let other = tag(of: child) {
                    if other.id != tagID { line.otherTags.append(other.label) }
                    continue
                }
                switch child["type"] as? String {
                case "text": words.append(child["text"] as? String ?? "")
                case "hardBreak": words.append(" ")
                case "mention": words.append((child["attrs"] as? [String: Any])?["label"] as? String ?? "")
                default: break
                }
            }
            line.text = words.joined()
                .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            result.append(line)
            return
        }
        for (index, child) in children(of: node).enumerated() {
            collect(child, path: path + [index], parent: node, grandparent: parent, tagID: tagID, into: &result)
        }
    }

    // MARK: Block ids (#113)

    private static let idTypes: Set<String> = ["paragraph", "heading", "taskItem", "listItem", "blockquote", "codeBlock"]

    private static func blockID(of node: Node) -> String? {
        (node["attrs"] as? [String: Any])?[blockIDAttribute] as? String
    }

    /// Gives every block without a lasting id one, as the editor does; nil
    /// when every block has one.
    static func ensuringBlockIDs(in json: String) -> String? {
        guard let doc = PageDocument.parse(json) else { return nil }
        var changed = false
        var seen = Set<String>()
        func visit(_ node: Node) -> Node {
            var node = node
            let type = node["type"] as? String ?? ""
            if type == syncedBlockType { return node }
            if idTypes.contains(type) {
                var attrs = node["attrs"] as? [String: Any] ?? [:]
                if let id = attrs[blockIDAttribute] as? String, !seen.contains(id) {
                    seen.insert(id)
                } else {
                    let id = UUID().uuidString
                    attrs[blockIDAttribute] = id
                    seen.insert(id)
                    node["attrs"] = attrs
                    changed = true
                }
            }
            if let content = node["content"] as? [Node] { node["content"] = content.map(visit) }
            return node
        }
        let result = visit(doc)
        return changed ? TipTapDocument.json(result) : nil
    }

    /// Where the block with `blockID` is: the path to it.
    static func path(ofBlock blockID: String, in json: String) -> [Int]? {
        guard json.contains(blockID), let doc = PageDocument.parse(json) else { return nil }
        return find(blockID, in: doc, path: [])?.path
    }

    private static func find(_ blockID: String, in node: Node, path: [Int]) -> (path: [Int], node: Node)? {
        for (index, child) in children(of: node).enumerated() {
            if (child["type"] as? String) == syncedBlockType { continue }
            if self.blockID(of: child) == blockID { return (path + [index], child) }
            if let found = find(blockID, in: child, path: path + [index]) { return found }
        }
        return nil
    }

    /// A synced block edited on a tag page, written back where it lives: the
    /// block's line gets `inline`, a to-do gets `checked`. Nil when the
    /// block isn't here or nothing changes.
    static func updating(block blockID: String, inline: [Node], checked: Bool?, in json: String) -> String? {
        guard json.contains(blockID), var doc = PageDocument.parse(json),
              let found = find(blockID, in: doc, path: []) else { return nil }
        var changed = false
        doc = update(doc, at: found.path[...]) { unit in
            var unit = unit
            if let checked, unit["type"] as? String == "taskItem" {
                var attrs = unit["attrs"] as? [String: Any] ?? [:]
                if (attrs["checked"] as? Bool ?? false) != checked {
                    attrs["checked"] = checked
                    unit["attrs"] = attrs
                    changed = true
                }
            }
            func setLine(_ textblock: Node) -> Node {
                var textblock = textblock
                let old = TipTapDocument.json(["c": textblock["content"] as? [Node] ?? []])
                if old != TipTapDocument.json(["c": inline]) {
                    textblock["content"] = inline
                    changed = true
                }
                return textblock
            }
            let type = unit["type"] as? String
            if type == "paragraph" || type == "heading" { return setLine(unit) }
            var content = children(of: unit)
            if let first = content.first, ["paragraph", "heading"].contains(first["type"] as? String ?? "") {
                content[0] = setLine(first)
                unit["content"] = content
            }
            return unit
        }
        return changed ? TipTapDocument.json(doc) : nil
    }

    /// A block made with Return in a synced block: added where that block
    /// lives, right after it, of the same kind. Nil when `after` isn't here.
    static func inserting(after: String, kind: LineKind, blockID: String, inline: [Node], in json: String) -> String? {
        guard json.contains(after), var doc = PageDocument.parse(json),
              let found = find(after, in: doc, path: []), let index = found.path.last else { return nil }
        let paragraph: Node = ["type": "paragraph", "content": inline]
        let node: Node
        switch found.node["type"] as? String {
        case "taskItem":
            node = ["type": "taskItem", "attrs": ["checked": false, blockIDAttribute: blockID], "content": [paragraph]]
        case "listItem":
            node = ["type": "listItem", "attrs": [blockIDAttribute: blockID], "content": [paragraph]]
        default:
            var p = paragraph
            p["attrs"] = [blockIDAttribute: blockID]
            node = p
        }
        _ = kind
        doc = update(doc, at: found.path.dropLast()[...]) { parent in
            var parent = parent
            var content = children(of: parent)
            content.insert(node, at: min(index + 1, content.count))
            parent["content"] = content
            return parent
        }
        return TipTapDocument.json(doc)
    }

    /// Takes `tagID` off the block: its chips go. A block left with no words
    /// is removed. Nil when nothing changes.
    static func removing(_ tagID: UUID, fromBlock blockID: String, in json: String) -> String? {
        guard json.contains(blockID), var doc = PageDocument.parse(json),
              let found = find(blockID, in: doc, path: []) else { return nil }
        var empty = false
        let unit = mapInline(found.node) { child in
            guard let tag = tag(of: child), tag.id == tagID else { return [child] }
            return []
        }
        var words: [String] = []
        walk(unit) { node in
            if node["type"] as? String == "text" { words.append(node["text"] as? String ?? "") }
            if node["type"] as? String == "mention" { words.append("x") }
        }
        empty = words.joined().trimmingCharacters(in: .whitespaces).isEmpty
        if empty { return deleting(block: blockID, in: json) }
        doc = update(doc, at: found.path[...]) { _ in trimmingLineEnds(unit) }
        return TipTapDocument.json(doc)
    }

    /// The space a removed chip leaves at the end of a line goes too.
    private static func trimmingLineEnds(_ node: Node) -> Node {
        var node = node
        let type = node["type"] as? String
        guard var content = node["content"] as? [Node] else { return node }
        if type == "paragraph" || type == "heading" {
            while let last = content.last, last["type"] as? String == "text" {
                let trimmed = (last["text"] as? String ?? "").replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
                if trimmed.isEmpty { content.removeLast(); continue }
                var text = last
                text["text"] = trimmed
                content[content.count - 1] = text
                break
            }
        } else {
            content = content.map(trimmingLineEnds)
        }
        node["content"] = content
        return node
    }

    /// Deletes the block where it lives. A list left empty goes too.
    static func deleting(block blockID: String, in json: String) -> String? {
        guard json.contains(blockID), var doc = PageDocument.parse(json),
              let found = find(blockID, in: doc, path: []), let index = found.path.last else { return nil }
        doc = update(doc, at: found.path.dropLast()[...]) { parent in
            var parent = parent
            var content = children(of: parent)
            content.remove(at: index)
            parent["content"] = content
            return parent
        }
        // An emptied list (or quote) goes as well.
        if found.path.count >= 2 {
            let parentPath = Array(found.path.dropLast())
            var cursor: Node? = doc
            for i in parentPath { cursor = cursor.flatMap { children(of: $0).indices.contains(i) ? children(of: $0)[i] : nil } }
            if let parent = cursor, children(of: parent).isEmpty, let last = parentPath.last {
                doc = update(doc, at: parentPath.dropLast()[...]) { grand in
                    var grand = grand
                    var content = children(of: grand)
                    content.remove(at: last)
                    grand["content"] = content
                    return grand
                }
            }
        }
        if children(of: doc).isEmpty { doc["content"] = [["type": "paragraph"]] }
        return TipTapDocument.json(doc)
    }

    // MARK: Changing

    /// Ticks or unticks the to-do at `path`; nil when there is none.
    static func settingChecked(_ checked: Bool, at path: [Int], in json: String) -> String? {
        guard var doc = PageDocument.parse(json) else { return nil }
        var found = false
        doc = update(doc, at: path[...]) { item in
            guard item["type"] as? String == "taskItem" else { return item }
            var item = item
            var attrs = item["attrs"] as? [String: Any] ?? [:]
            attrs["checked"] = checked
            item["attrs"] = attrs
            found = true
            return item
        }
        return found ? TipTapDocument.json(doc) : nil
    }

    /// Gives every chip of `tagID` the label `label`; nil when nothing changes.
    static func relabeling(_ tagID: UUID, to label: String, in json: String) -> String? {
        guard json.contains(tagID.uuidString), let doc = PageDocument.parse(json) else { return nil }
        var changed = false
        let result = mapInline(doc) { child in
            guard let tag = tag(of: child), tag.id == tagID, tag.label != label else { return [child] }
            var child = child
            var attrs = child["attrs"] as? [String: Any] ?? [:]
            attrs["label"] = label
            child["attrs"] = attrs
            changed = true
            return [child]
        }
        return changed ? TipTapDocument.json(result) : nil
    }

    /// Turns every chip of `tagID` back into its name as plain text (the #
    /// goes, the word stays); nil when there are none.
    static func removing(_ tagID: UUID, in json: String) -> String? {
        guard json.contains(tagID.uuidString), let doc = PageDocument.parse(json) else { return nil }
        var changed = false
        let result = mapInline(doc) { child in
            guard let tag = tag(of: child), tag.id == tagID else { return [child] }
            changed = true
            return tag.label.isEmpty ? [] : [["type": "text", "text": tag.label]]
        }
        return changed ? TipTapDocument.json(result) : nil
    }

    // MARK: Task titles

    /// Whether a task title carries "#name" as a word, ignoring case.
    static func title(_ title: String, hasTag name: String) -> Bool {
        title.range(of: pattern(for: name), options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// "#old" becomes "#new" in a task title.
    static func renamingTag(in title: String, from old: String, to new: String) -> String {
        replacing(in: title, tag: old) { "#" + new }
    }

    /// A task title without its "#name", for the tag page that shows it.
    static func strippingTag(from title: String, named name: String) -> String {
        replacing(in: title, tag: name) { "" }
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// "#name" becomes "name" in a task title.
    static func removingTag(from title: String, named name: String) -> String {
        replacing(in: title, tag: name) { name }
    }

    private static func pattern(for name: String) -> String {
        "(?<![\\p{L}\\p{N}_#])#" + NSRegularExpression.escapedPattern(for: name) + "(?![\\p{L}\\p{N}_\\-/])"
    }

    private static func replacing(in title: String, tag name: String, with replacement: () -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern(for: name), options: [.caseInsensitive]) else { return title }
        let range = NSRange(title.startIndex..., in: title)
        return regex.stringByReplacingMatches(in: title, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: replacement()))
    }

    // MARK: Tree helpers

    private static func tag(of node: Node) -> Tag? {
        guard node["type"] as? String == "mention",
              let attrs = node["attrs"] as? [String: Any],
              attrs["kind"] as? String == mentionKind,
              let id = (attrs["id"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        return Tag(id: id, label: attrs["label"] as? String ?? "")
    }

    private static func children(of node: Node) -> [Node] {
        node["content"] as? [Node] ?? []
    }

    private static func walk(_ node: Node, _ visit: (Node) -> Void) {
        visit(node)
        for child in children(of: node) { walk(child, visit) }
    }

    private static func update(_ node: Node, at path: ArraySlice<Int>, _ transform: (Node) -> Node) -> Node {
        guard let index = path.first else { return transform(node) }
        var content = children(of: node)
        guard content.indices.contains(index) else { return node }
        content[index] = update(content[index], at: path.dropFirst(), transform)
        var node = node
        node["content"] = content
        return node
    }

    /// Rewrites inline children of every block; `transform` returns what
    /// replaces each one.
    private static func mapInline(_ node: Node, _ transform: (Node) -> [Node]) -> Node {
        guard let content = node["content"] as? [Node] else { return node }
        var node = node
        node["content"] = content.flatMap { child -> [Node] in
            if child["type"] as? String == "mention" { return transform(child) }
            return [mapInline(child, transform)]
        }
        return node
    }
}

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
        if type == "paragraph" || type == "heading" {
            let inline = children(of: node)
            guard inline.contains(where: { tag(of: $0)?.id == tagID }) else { return }
            let parentType = parent?["type"] as? String
            let isFirstChild = path.last == 0
            var line = Line(path: path, kind: type == "heading" ? .heading : .paragraph, text: "", otherTags: [], isChecked: false)
            if let parent, isFirstChild, parentType == "taskItem" {
                let attrs = parent["attrs"] as? [String: Any] ?? [:]
                line.kind = .todo
                line.path = Array(path.dropLast())
                line.isChecked = attrs["checked"] as? Bool ?? false
                line.taskID = (attrs[PageDocument.taskIDAttribute] as? String).flatMap(UUID.init(uuidString:))
            } else if isFirstChild, parentType == "listItem" {
                line.kind = (grandparent?["type"] as? String) == "orderedList" ? .numbered : .bullet
                line.path = Array(path.dropLast())
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

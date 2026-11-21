//
//  PageDocument.swift
//  Schema
//
//  Reading and changing a page's TipTap document (#77) in Swift: its plain
//  text for search and list subtitles, its to-dos and the tasks they link
//  to, and the few edits the app makes without the editor (Quick note,
//  making tasks from open to-dos, keeping linked to-dos in step with their
//  tasks). Pure functions on JSON, so they are easy to test.
//

import Foundation

nonisolated enum PageDocument {
    typealias Node = TipTapDocument.Node

    /// A document with one empty paragraph: what a new page opens with.
    static let emptyJSON = TipTapDocument.json(TipTapDocument.document(from: [TipTapDocument.Line]()))

    /// The attribute on a TipTap task item that links it to a task.
    static let taskIDAttribute = "taskId"

    /// What lists, search and the task panel need from a document.
    struct Summary: Equatable {
        var text = ""
        var linkedTaskIDs: [UUID] = []
        var checklistCount = 0
        var checklistDoneCount = 0
    }

    /// A to-do line in the document.
    struct ToDo: Equatable {
        var text: String
        var isChecked: Bool
        var taskID: UUID?
    }

    static func parse(_ json: String) -> Node? {
        guard let data = json.data(using: .utf8),
              let node = try? JSONSerialization.jsonObject(with: data) as? Node else { return nil }
        return node
    }

    static func summary(of json: String) -> Summary {
        guard let node = parse(json) else { return Summary() }
        let todos = toDos(in: node)
        return Summary(
            text: plainText(node),
            linkedTaskIDs: todos.compactMap(\.taskID),
            checklistCount: todos.count,
            checklistDoneCount: todos.count { $0.isChecked }
        )
    }

    // MARK: Reading

    /// Block text separated by new lines; Shift+Enter breaks are new lines too.
    static func plainText(_ node: Node) -> String {
        var lines: [String] = []
        collectText(node, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static let textBlocks: Set<String> = ["paragraph", "heading", "codeBlock"]

    private static func collectText(_ node: Node, into lines: inout [String]) {
        let type = node["type"] as? String
        if let type, textBlocks.contains(type) {
            let text = inlineText(node)
            if !text.isEmpty { lines.append(text) }
            return
        }
        for child in children(of: node) { collectText(child, into: &lines) }
    }

    private static func inlineText(_ node: Node) -> String {
        children(of: node).map { child in
            switch child["type"] as? String {
            case "text": child["text"] as? String ?? ""
            case "hardBreak": "\n"
            case "mention": (child["attrs"] as? [String: Any])?["label"] as? String ?? ""
            default: inlineText(child)
            }
        }.joined()
    }

    static func toDos(in node: Node) -> [ToDo] {
        var result: [ToDo] = []
        walk(node) { item in
            guard item["type"] as? String == "taskItem" else { return }
            let attrs = item["attrs"] as? [String: Any] ?? [:]
            let id = (attrs[taskIDAttribute] as? String).flatMap(UUID.init(uuidString:))
            let firstBlock = children(of: item).first.map(inlineText) ?? ""
            result.append(ToDo(text: firstBlock, isChecked: attrs["checked"] as? Bool ?? false, taskID: id))
        }
        return result
    }

    // MARK: Changing

    /// Ticks or unticks linked to-dos to match their tasks. Returns `json`
    /// itself when nothing changes, so the editor is not reloaded.
    static func applyingTaskStates(to json: String, isDone: (UUID) -> Bool?) -> String {
        guard json.contains(taskIDAttribute), var node = parse(json) else { return json }
        var changed = false
        node = mapTaskItems(node) { item in
            var attrs = item["attrs"] as? [String: Any] ?? [:]
            guard let id = (attrs[taskIDAttribute] as? String).flatMap(UUID.init(uuidString:)),
                  let done = isDone(id), (attrs["checked"] as? Bool ?? false) != done else { return item }
            var item = item
            attrs["checked"] = done
            item["attrs"] = attrs
            changed = true
            return item
        }
        return changed ? TipTapDocument.json(node) : json
    }

    /// Linked tasks whose done state differs from their to-do in `json`:
    /// the editor ticked or unticked them, so the tasks follow.
    static func tasksToToggle(in json: String, isDone: (UUID) -> Bool?) -> [UUID] {
        guard json.contains(taskIDAttribute), let node = parse(json) else { return [] }
        return toDos(in: node).compactMap { todo in
            guard let id = todo.taskID, let done = isDone(id), done != todo.isChecked else { return nil }
            return id
        }
    }

    /// Makes a task from every open to-do with text and no task yet, and
    /// links the line to it. `makeTask` returns the new task's id.
    static func linkingOpenToDos(in json: String, makeTask: (String) -> UUID?) -> (json: String, made: Int) {
        guard var node = parse(json) else { return (json, 0) }
        var made = 0
        node = mapTaskItems(node) { item in
            var attrs = item["attrs"] as? [String: Any] ?? [:]
            let text = children(of: item).first.map(inlineText)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard attrs["checked"] as? Bool != true, attrs[taskIDAttribute] as? String == nil, !text.isEmpty,
                  let id = makeTask(text) else { return item }
            var item = item
            attrs[taskIDAttribute] = id.uuidString
            item["attrs"] = attrs
            made += 1
            return item
        }
        return (made > 0 ? TipTapDocument.json(node) : json, made)
    }

    /// Open to-dos that could still become tasks.
    static func openToDosWithoutTasks(in json: String) -> [ToDo] {
        guard let node = parse(json) else { return [] }
        return toDos(in: node).filter {
            !$0.isChecked && $0.taskID == nil && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Quick note: `lines` go under `heading` at the top of the document,
    /// newest first. Today's heading is reused when it is already on top.
    static func prependingNote(_ lines: [TipTapDocument.Line], under heading: String, to json: String) -> String {
        prependingNote(blocks: children(of: TipTapDocument.document(from: lines)), under: heading, to: json)
    }

    /// Quick note in the editor (#82): the note's own blocks go under
    /// `heading`, without empty lines at its start or end.
    static func prependingNote(json noteJSON: String, under heading: String, to json: String) -> String {
        var blocks = parse(noteJSON).map(children(of:)) ?? []
        let isEmptyLine = { (node: Node) in node["type"] as? String == "paragraph" && inlineText(node).trimmingCharacters(in: .whitespaces).isEmpty }
        while let first = blocks.first, isEmptyLine(first) { blocks.removeFirst() }
        while let last = blocks.last, isEmptyLine(last) { blocks.removeLast() }
        return prependingNote(blocks: blocks, under: heading, to: json)
    }

    private static func prependingNote(blocks note: [Node], under heading: String, to json: String) -> String {
        var node = parse(json) ?? TipTapDocument.document(from: [TipTapDocument.Line]())
        var content = children(of: node)
        // An untouched page holds one empty paragraph: replace it.
        if content.count == 1, content[0]["type"] as? String == "paragraph", children(of: content[0]).isEmpty {
            content = []
        }
        if let first = content.first, first["type"] as? String == "heading", inlineText(first) == heading {
            content.insert(contentsOf: note, at: 1)
        } else {
            let top = children(of: TipTapDocument.document(from: [TipTapDocument.Line(kind: .heading, text: heading)]))
            content.insert(contentsOf: top + note, at: 0)
        }
        node["content"] = content
        return TipTapDocument.json(node)
    }

    // MARK: Tree helpers

    private static func children(of node: Node) -> [Node] {
        node["content"] as? [Node] ?? []
    }

    private static func walk(_ node: Node, _ visit: (Node) -> Void) {
        visit(node)
        for child in children(of: node) { walk(child, visit) }
    }

    private static func mapTaskItems(_ node: Node, _ transform: (Node) -> Node) -> Node {
        var node = node
        if node["type"] as? String == "taskItem" { node = transform(node) }
        if let content = node["content"] as? [Node] {
            node["content"] = content.map { mapTaskItems($0, transform) }
        }
        return node
    }
}

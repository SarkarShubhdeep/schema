//
//  TipTapDocument.swift
//  Schema
//
//  Turns the v0.5 lines of a page into a TipTap (ProseMirror) document: used
//  by the V7 migration (#77) and Quick note. Consecutive bullets
//  become one bullet list and consecutive to-dos one task list, the way
//  TipTap groups them.
//

import Foundation

nonisolated enum TipTapDocument {
    typealias Node = [String: Any]

    struct Line: Equatable {
        var kind: BlockKind
        var text: String
        var isChecked: Bool = false
        /// The task a to-do was made into ("Make task", #40).
        var taskID: UUID?
    }

    @MainActor static func document(from blocks: [SchemaBlock]) -> Node {
        document(from: blocks.inDisplayOrder.map {
            Line(kind: $0.kind, text: $0.text, isChecked: $0.isChecked, taskID: $0.linkedTaskID)
        })
    }

    static func document(from lines: [Line]) -> Node {
        var content: [Node] = []
        var index = lines.startIndex
        while index < lines.endIndex {
            let line = lines[index]
            switch line.kind {
            case .bullet, .todo:
                // Gather the run of the same kind into one list.
                var items: [Node] = []
                while index < lines.endIndex, lines[index].kind == line.kind {
                    items.append(listItem(lines[index]))
                    index += 1
                }
                content.append(["type": line.kind == .todo ? "taskList" : "bulletList", "content": items])
                continue
            case .text:
                content.append(paragraph(line.text))
            case .heading:
                content.append(["type": "heading", "attrs": ["level": 2], "content": inline(line.text)])
            case .quote:
                content.append(["type": "blockquote", "content": [paragraph(line.text)]])
            case .divider:
                content.append(["type": "horizontalRule"])
            }
            index += 1
        }
        if content.isEmpty { content = [paragraph("")] }
        return ["type": "doc", "content": content]
    }

    /// The document as JSON text, ready to hand to the editor.
    static func json(_ node: Node) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: node, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return #"{"type":"doc","content":[]}"# }
        return text
    }

    private static func listItem(_ line: Line) -> Node {
        if line.kind == .todo {
            var attrs: [String: Any] = ["checked": line.isChecked]
            if let taskID = line.taskID { attrs[PageDocument.taskIDAttribute] = taskID.uuidString }
            return ["type": "taskItem", "attrs": attrs, "content": [paragraph(line.text)]]
        }
        return ["type": "listItem", "content": [paragraph(line.text)]]
    }

    private static func paragraph(_ text: String) -> Node {
        let children = inline(text)
        return children.isEmpty ? ["type": "paragraph"] : ["type": "paragraph", "content": children]
    }

    /// Text with its line breaks kept as hard breaks (Shift+Enter in TipTap).
    private static func inline(_ text: String) -> [Node] {
        var nodes: [Node] = []
        for (offset, part) in text.components(separatedBy: "\n").enumerated() {
            if offset > 0 { nodes.append(["type": "hardBreak"]) }
            if !part.isEmpty { nodes.append(["type": "text", "text": part]) }
        }
        return nodes
    }
}

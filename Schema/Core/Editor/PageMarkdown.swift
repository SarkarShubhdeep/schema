//
//  PageMarkdown.swift
//  Schema
//
//  A page's TipTap document as Markdown (#79), for Copy as Markdown and
//  Export as Markdown. One writer in Swift, so a page copied from its menu
//  and a block copied from its handle read the same. Headings, lists
//  (bullet, numbered, to-do, nested), quotes, code, dividers, bold,
//  italic, strikethrough, inline code and links; underline has no Markdown
//  and is left as plain text.
//

import Foundation

nonisolated enum PageMarkdown {
    typealias Node = TipTapDocument.Node

    /// The document as Markdown, with the title as its first heading when given.
    static func markdown(fromJSON json: String, title: String? = nil) -> String {
        let body = PageDocument.parse(json).map(markdown(from:)) ?? ""
        let heading = title.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let parts = [heading.isEmpty ? "" : "# " + escapeInline(heading), body].filter { !$0.isEmpty }
        return parts.isEmpty ? "" : parts.joined(separator: "\n\n") + "\n"
    }

    static func markdown(from document: Node) -> String {
        blocks(children(of: document)).joined(separator: "\n\n")
    }

    /// A file name for the page: its title without characters Finder dislikes.
    static func fileName(for title: String) -> String {
        let cleaned = title
            .components(separatedBy: CharacterSet(charactersIn: "/:\\").union(.whitespacesAndNewlines))
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return (cleaned.isEmpty ? "Untitled" : cleaned) + ".md"
    }

    // MARK: Blocks

    private static func blocks(_ nodes: [Node]) -> [String] {
        nodes.compactMap { block($0) }
    }

    /// One block's Markdown, or nil for an empty line.
    private static func block(_ node: Node) -> String? {
        switch type(of: node) {
        case "paragraph":
            let text = inline(children(of: node))
            return text.isEmpty ? nil : escapeLineStart(text)
        case "heading":
            let level = min(max((attrs(of: node)["level"] as? Int) ?? 1, 1), 6)
            let text = inline(children(of: node))
            return text.isEmpty ? nil : String(repeating: "#", count: level) + " " + text
        case "bulletList":
            return list(node) { _, _ in "- " }
        case "orderedList":
            let start = (attrs(of: node)["start"] as? Int) ?? 1
            return list(node) { index, _ in "\(start + index). " }
        case "taskList":
            return list(node) { _, item in (attrs(of: item)["checked"] as? Bool) == true ? "- [x] " : "- [ ] " }
        case "blockquote":
            let inner = blocks(children(of: node)).joined(separator: "\n\n")
            guard !inner.isEmpty else { return nil }
            return inner.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.isEmpty ? ">" : "> " + $0 }
                .joined(separator: "\n")
        case "codeBlock":
            let text = children(of: node).compactMap { $0["text"] as? String }.joined()
            let language = (attrs(of: node)["language"] as? String) ?? ""
            let fence = text.contains("```") ? "~~~" : "```"
            return fence + language + "\n" + text + "\n" + fence
        case "horizontalRule":
            return "---"
        default:
            let text = inline(children(of: node))
            return text.isEmpty ? nil : text
        }
    }

    /// A list, one item per line. An item's later paragraphs and nested
    /// lists are indented under its text.
    private static func list(_ node: Node, marker: (Int, Node) -> String) -> String? {
        var lines: [String] = []
        for (index, item) in children(of: node).enumerated() {
            let mark = marker(index, item)
            let indent = String(repeating: " ", count: mark.hasPrefix("- ") ? 2 : mark.count)
            let parts = blocks(children(of: item))
            let first = parts.first ?? ""
            var itemLines = (mark + first).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if itemLines.count > 1 {
                itemLines = [itemLines[0]] + itemLines.dropFirst().map { $0.isEmpty ? "" : indent + $0 }
            }
            for part in parts.dropFirst() {
                itemLines += part.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? "" : indent + $0 }
            }
            lines += itemLines.map { $0 == mark ? String(mark.dropLast()) : $0 }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: Inline

    /// Marks in the order they open; the first opened closes last.
    private static let markOrder = ["link", "bold", "italic", "strike", "code"]

    private struct Mark {
        var name: String
        var href: String?
        /// Inline code holding a backtick is fenced with two.
        var isDoubleTick = false
    }

    private static func marks(of node: Node) -> [Mark] {
        let raw = (node["marks"] as? [Node]) ?? []
        return raw.compactMap { mark -> Mark? in
            guard let name = mark["type"] as? String, markOrder.contains(name) else { return nil }
            return Mark(name: name, href: name == "link" ? (attrs(of: mark)["href"] as? String) : nil)
        }
        .sorted { markOrder.firstIndex(of: $0.name)! < markOrder.firstIndex(of: $1.name)! }
    }

    /// Text runs with their marks opened and closed around them. Spaces at
    /// the edge of a mark go outside it, or Markdown would not see the mark.
    private static func inline(_ nodes: [Node]) -> String {
        var out = ""
        var open: [Mark] = []
        var pendingSpace = ""

        func close(downTo keep: Int) {
            while open.count > keep {
                out += closer(open.removeLast())
            }
        }

        for node in nodes {
            switch type(of: node) {
            case "text":
                let text = (node["text"] as? String) ?? ""
                let wanted = marks(of: node)
                let isCode = wanted.contains { $0.name == "code" }
                // Keep the marks that are still on, in order; close the rest.
                var keep = 0
                while keep < open.count, keep < wanted.count,
                      open[keep].name == wanted[keep].name, open[keep].href == wanted[keep].href { keep += 1 }
                let core = text.trimmingCharacters(in: .whitespaces)
                if core.isEmpty {
                    pendingSpace += text
                    continue
                }
                let leading = String(text.prefix { $0 == " " || $0 == "\t" })
                let trailing = String(text.reversed().prefix { $0 == " " || $0 == "\t" })
                close(downTo: keep)
                out += pendingSpace + leading
                pendingSpace = ""
                for var mark in wanted.dropFirst(keep) {
                    mark.isDoubleTick = mark.name == "code" && core.contains("`")
                    open.append(mark)
                    out += opener(mark)
                }
                out += isCode ? core : escapeInline(core)
                pendingSpace = trailing
            case "hardBreak":
                close(downTo: 0)
                out += "\\\n"
                pendingSpace = ""
            default:
                // A mention or other inline node: its label or text, if any.
                let label = (attrs(of: node)["label"] as? String) ?? (node["text"] as? String) ?? ""
                if !label.isEmpty {
                    close(downTo: 0)
                    out += pendingSpace + escapeInline(label)
                    pendingSpace = ""
                }
            }
        }
        close(downTo: 0)
        // Spaces at the end of a line mean nothing in Markdown.
        return out
    }

    private static func opener(_ mark: Mark) -> String {
        switch mark.name {
        case "link": "["
        case "bold": "**"
        case "italic": "_"
        case "strike": "~~"
        case "code": mark.isDoubleTick ? "`` " : "`"
        default: ""
        }
    }

    private static func closer(_ mark: Mark) -> String {
        switch mark.name {
        case "link": "](\(mark.href ?? ""))"
        case "code": mark.isDoubleTick ? " ``" : "`"
        default: opener(mark)
        }
    }

    // MARK: Escaping

    /// Characters that would otherwise read as Markdown inside a line. An
    /// underscore inside a word (snake_case) is left alone, as Markdown does.
    private static func escapeInline(_ text: String) -> String {
        let characters = Array(text)
        var out = ""
        for (index, character) in characters.enumerated() {
            if "\\*`[]".contains(character) {
                out.append("\\")
            } else if character == "_" {
                let before = index > 0 ? characters[index - 1] : " "
                let after = index + 1 < characters.count ? characters[index + 1] : " "
                if !(before.isLetter || before.isNumber) || !(after.isLetter || after.isNumber) { out.append("\\") }
            } else if character == "~", index + 1 < characters.count, characters[index + 1] == "~" {
                out.append("\\")
            }
            out.append(character)
        }
        return out
    }

    /// A paragraph that starts like a heading, list or quote stays a paragraph.
    private static func escapeLineStart(_ text: String) -> String {
        if text.hasPrefix("#") || text.hasPrefix(">") || text.hasPrefix("- ") || text.hasPrefix("+ ") || text == "---" {
            return "\\" + text
        }
        let digits = text.prefix { $0.isASCII && $0.isNumber }
        let rest = text.dropFirst(digits.count)
        if !digits.isEmpty, rest.hasPrefix(". ") || rest.hasPrefix(") ") {
            return digits + "\\" + rest
        }
        return text
    }

    // MARK: Nodes

    private static func type(of node: Node) -> String { (node["type"] as? String) ?? "" }
    private static func attrs(of node: Node) -> [String: Any] { (node["attrs"] as? [String: Any]) ?? [:] }
    private static func children(of node: Node) -> [Node] { (node["content"] as? [Node]) ?? [] }
}

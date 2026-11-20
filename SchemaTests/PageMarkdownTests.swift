//
//  PageMarkdownTests.swift
//  SchemaTests
//
//  A page's TipTap document written as Markdown (#79), for Copy as
//  Markdown and Export as Markdown.
//

import Foundation
import Testing
@testable import Schema

struct PageMarkdownTests {
    private func text(_ string: String, _ marks: [String] = [], href: String? = nil) -> [String: Any] {
        var node: [String: Any] = ["type": "text", "text": string]
        if !marks.isEmpty {
            node["marks"] = marks.map { name -> [String: Any] in
                name == "link" ? ["type": name, "attrs": ["href": href ?? ""]] : ["type": name]
            }
        }
        return node
    }

    private func paragraph(_ content: [[String: Any]]) -> [String: Any] {
        ["type": "paragraph", "content": content]
    }

    private func markdown(_ blocks: [[String: Any]], title: String? = nil) -> String {
        PageMarkdown.markdown(fromJSON: TipTapDocument.json(["type": "doc", "content": blocks]), title: title)
    }

    @Test func blocksBecomeMarkdown() {
        let md = markdown([
            ["type": "heading", "attrs": ["level": 2], "content": [text("Plan")]],
            paragraph([text("Hello")]),
            ["type": "paragraph"],
            ["type": "bulletList", "content": [
                ["type": "listItem", "content": [paragraph([text("one")])]],
                ["type": "listItem", "content": [
                    paragraph([text("two")]),
                    ["type": "bulletList", "content": [["type": "listItem", "content": [paragraph([text("nested")])]]]],
                ]],
            ]],
            ["type": "orderedList", "attrs": ["start": 3], "content": [
                ["type": "listItem", "content": [paragraph([text("third")])]],
                ["type": "listItem", "content": [paragraph([text("fourth")])]],
            ]],
            ["type": "taskList", "content": [
                ["type": "taskItem", "attrs": ["checked": false, "taskId": "x"], "content": [paragraph([text("open")])]],
                ["type": "taskItem", "attrs": ["checked": true], "content": [paragraph([text("done")])]],
            ]],
            ["type": "blockquote", "content": [paragraph([text("said")]), paragraph([text("twice")])]],
            ["type": "codeBlock", "attrs": ["language": "swift"], "content": [text("let a = 1\nlet b = 2")]],
            ["type": "horizontalRule"],
        ], title: "Ideas")

        #expect(md == """
        # Ideas

        ## Plan

        Hello

        - one
        - two
          - nested

        3. third
        4. fourth

        - [ ] open
        - [x] done

        > said
        >
        > twice

        ```swift
        let a = 1
        let b = 2
        ```

        ---

        """)
    }

    @Test func marksOpenAndCloseInOrder() {
        let md = markdown([paragraph([
            text("Plain "),
            text("bold ", ["bold"]),
            text("both", ["bold", "italic"]),
            text(" and "),
            text("code", ["code"]),
            text(", "),
            text("gone", ["strike"]),
            text(", "),
            text("site", ["link"], href: "https://example.com"),
            text(" "),
            text("under", ["underline"]),
        ])])
        #expect(md == "Plain **bold _both_** and `code`, ~~gone~~, [site](https://example.com) under\n")
    }

    @Test func spacesStayOutsideMarks() {
        let md = markdown([paragraph([text("a"), text(" b ", ["bold"]), text("c")])])
        #expect(md == "a **b** c\n")
    }

    @Test func hardBreaksAndListContinuation() {
        let md = markdown([
            paragraph([text("one"), ["type": "hardBreak"], text("two")]),
            ["type": "bulletList", "content": [
                ["type": "listItem", "content": [paragraph([text("a"), ["type": "hardBreak"], text("b")])]],
            ]],
        ])
        #expect(md == "one\\\ntwo\n\n- a\\\n  b\n")
    }

    @Test func markdownCharactersInTextAreEscaped() {
        let md = markdown([
            paragraph([text("2*3 is [six] and file_name, _x_ ~~y~~")]),
            paragraph([text("# not a heading")]),
            paragraph([text("1. not a list")]),
            paragraph([text("`raw` stays", ["code"])]),
        ])
        #expect(md == """
        2\\*3 is \\[six\\] and file_name, \\_x\\_ \\~~y\\~~

        \\# not a heading

        1\\. not a list

        `` `raw` stays ``

        """)
    }

    @Test func emptyDocumentIsEmpty() {
        #expect(PageMarkdown.markdown(fromJSON: PageDocument.emptyJSON) == "")
        #expect(PageMarkdown.markdown(fromJSON: PageDocument.emptyJSON, title: "Ideas") == "# Ideas\n")
    }

    @Test func fileNameComesFromTheTitle() {
        #expect(PageMarkdown.fileName(for: "Q3 / plan: draft") == "Q3 plan draft.md")
        #expect(PageMarkdown.fileName(for: "  ") == "Untitled.md")
    }
}

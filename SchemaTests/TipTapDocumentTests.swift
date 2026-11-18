//
//  TipTapDocumentTests.swift
//  SchemaTests
//
//  v0.5 lines become the TipTap document the new editor opens (#76).
//

import Foundation
import Testing
@testable import Schema

struct TipTapDocumentTests {
    private typealias Line = TipTapDocument.Line

    private func types(_ node: TipTapDocument.Node) -> [String] {
        (node["content"] as? [TipTapDocument.Node] ?? []).compactMap { $0["type"] as? String }
    }

    @Test func runsOfBulletsAndToDosBecomeOneListEach() {
        let doc = TipTapDocument.document(from: [
            Line(kind: .text, text: "Intro"),
            Line(kind: .bullet, text: "One"),
            Line(kind: .bullet, text: "Two"),
            Line(kind: .todo, text: "Do it", isChecked: true),
            Line(kind: .todo, text: "Then this"),
            Line(kind: .heading, text: "Questions"),
            Line(kind: .quote, text: "Why?"),
            Line(kind: .divider, text: ""),
        ])
        #expect(types(doc) == ["paragraph", "bulletList", "taskList", "heading", "blockquote", "horizontalRule"])

        let lists = doc["content"] as? [TipTapDocument.Node] ?? []
        #expect((lists[1]["content"] as? [Any])?.count == 2)
        let tasks = lists[2]["content"] as? [TipTapDocument.Node] ?? []
        #expect((tasks[0]["attrs"] as? [String: Any])?["checked"] as? Bool == true)
        #expect((tasks[1]["attrs"] as? [String: Any])?["checked"] as? Bool == false)
    }

    @Test func lineBreaksInsideALineBecomeHardBreaks() {
        let doc = TipTapDocument.document(from: [Line(kind: .text, text: "First\nSecond")])
        let paragraph = (doc["content"] as? [TipTapDocument.Node])?.first
        let inline = (paragraph?["content"] as? [TipTapDocument.Node] ?? []).compactMap { $0["type"] as? String }
        #expect(inline == ["text", "hardBreak", "text"])
    }

    @Test func anEmptyPageStillHasOneParagraph() {
        let doc = TipTapDocument.document(from: [Line]())
        #expect(types(doc) == ["paragraph"])
        #expect(TipTapDocument.json(doc) == #"{"content":[{"type":"paragraph"}],"type":"doc"}"#)
    }
}

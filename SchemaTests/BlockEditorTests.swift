//
//  BlockEditorTests.swift
//  SchemaTests
//
//  Return, Backspace and arrows in the block editor (#38).
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct BlockEditorTests {
    let container: ModelContainer
    let page: SchemaList
    let editor: BlockEditor

    init() throws {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        page = SchemaList(title: "Ideas", kind: .scratchpad)
        container.mainContext.insert(page)
        editor = BlockEditor(owner: .page(page), context: container.mainContext)
    }

    private func add(_ kind: BlockKind, _ text: String) -> SchemaBlock {
        editor.insertBlock(after: editor.blocks.last, kind: kind, text: text)
    }

    private var texts: [String] { editor.blocks.map(\.text) }
    private var kinds: [BlockKind] { editor.blocks.map(\.kind) }

    @Test func focusEndOnAnEmptyPageAddsTheFirstLine() {
        editor.focusEnd()
        #expect(editor.blocks.count == 1)
        #expect(editor.focusRequest?.blockID == editor.blocks.first?.id)
        // A second click reuses the empty line.
        editor.focusEnd()
        #expect(editor.blocks.count == 1)
    }

    @Test func returnSplitsTextAtTheCaret() {
        let block = add(.text, "Hello world")
        editor.splitBlock(block, at: 5)
        #expect(texts == ["Hello", " world"])
        #expect(editor.focusRequest?.blockID == editor.blocks[1].id)
        #expect(editor.focusRequest?.caret == .start)
    }

    @Test func returnAtTheEndOfAHeadingStartsText() {
        let heading = add(.heading, "Questions")
        editor.splitBlock(heading, at: 9)
        #expect(kinds == [.heading, .text])
    }

    @Test func bulletsAndToDosContinueAndEndOnAnEmptyLine() {
        let bullet = add(.bullet, "One")
        editor.splitBlock(bullet, at: 3)
        #expect(kinds == [.bullet, .bullet])

        let empty = editor.blocks[1]
        editor.splitBlock(empty, at: 0)
        #expect(kinds == [.bullet, .text])
        #expect(editor.blocks.count == 2)
    }

    @Test func returnAtTheStartOpensALineAbove() {
        let block = add(.text, "Keep me")
        editor.splitBlock(block, at: 0)
        #expect(texts == ["", "Keep me"])
        #expect(editor.focusRequest?.blockID == block.id)
    }

    @Test func backspaceAtStartTurnsAKindBackIntoText() {
        let todo = add(.todo, "Sketch")
        editor.backspaceAtStart(of: todo)
        #expect(kinds == [.text])
        #expect(texts == ["Sketch"])
    }

    @Test func backspaceAtStartJoinsTextWithTheLineAbove() {
        _ = add(.text, "Hello")
        let second = add(.text, " world")
        editor.backspaceAtStart(of: second)
        #expect(texts == ["Hello world"])
        #expect(editor.focusRequest?.caret == .offset(5))
    }

    @Test func backspaceAfterADividerRemovesTheDivider() {
        _ = add(.text, "Above")
        _ = add(.divider, "")
        let below = add(.text, "Below")
        editor.backspaceAtStart(of: below)
        #expect(kinds == [.text, .text])
        #expect(texts == ["Above", "Below"])
    }

    @Test func backspaceOnTheFirstLineDoesNothing() {
        let first = add(.text, "Only")
        editor.backspaceAtStart(of: first)
        #expect(texts == ["Only"])
    }

    @Test func arrowsSkipDividers() {
        let top = add(.text, "Top")
        _ = add(.divider, "")
        let bottom = add(.text, "Bottom")
        editor.focusPrevious(of: bottom)
        #expect(editor.focusRequest?.blockID == top.id)
        #expect(editor.focusRequest?.caret == .end)
        editor.focusNext(of: top)
        #expect(editor.focusRequest?.blockID == bottom.id)
    }

    @Test func manyInsertsInTheSameGapKeepOrder() {
        let first = add(.text, "first")
        _ = add(.text, "last")
        var anchor = first
        for index in 0..<80 {
            anchor = editor.insertBlock(after: anchor, kind: .text, text: "\(index)")
        }
        #expect(texts.first == "first")
        #expect(texts.last == "last")
        #expect(Array(texts.dropFirst().dropLast()) == (0..<80).map(String.init))
    }

    @Test func emojiOffsetsCountUTF16() {
        let block = add(.text, "👋 hi")
        // "👋" is two UTF-16 units; the caret after it is at 2.
        editor.splitBlock(block, at: 2)
        #expect(texts == ["👋", " hi"])
    }
}

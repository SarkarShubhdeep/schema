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

    // MARK: Markdown shortcuts (#39)

    @Test(arguments: [
        ("# ", BlockKind.heading), ("## ", .heading), ("- ", .bullet), ("* ", .bullet),
        ("[] ", .todo), ("[ ] ", .todo), ("> ", .quote),
    ])
    func markdownPrefixTurnsTheLineIntoAKind(prefix: String, kind: BlockKind) {
        let block = add(.text, "")
        editor.userTyped(prefix, in: block)
        #expect(block.kind == kind)
        #expect(block.text.isEmpty)
    }

    @Test func markdownPrefixKeepsTheRestOfTheLine() {
        let block = add(.text, "")
        editor.userTyped("- milk", in: block)
        // Only a prefix typed on its own converts; "- milk" arrives in one
        // change only from a paste, and still converts.
        #expect(block.kind == .bullet)
        #expect(block.text == "milk")
    }

    @Test func threeDashesMakeADividerAndANewLine() {
        let block = add(.text, "")
        editor.userTyped("---", in: block)
        #expect(kinds == [.divider, .text])
        #expect(editor.focusRequest?.blockID == editor.blocks[1].id)
    }

    @Test func markdownOnlyAppliesToTextLines() {
        let heading = add(.heading, "")
        editor.userTyped("- ", in: heading)
        #expect(heading.kind == .heading)
        #expect(heading.text == "- ")
    }

    // MARK: Slash menu (#39)

    @Test func slashOpensTheMenuAndLettersFilterIt() {
        let block = add(.text, "")
        editor.userTyped("/", in: block)
        #expect(editor.isMenuOpen(on: block))
        #expect(editor.menuItems == BlockKind.allCases)

        editor.userTyped("/to", in: block)
        #expect(editor.menuItems == [.todo])

        editor.userTyped("/h", in: block)
        #expect(editor.menuItems.first == .heading)
    }

    @Test func choosingFromTheMenuRemovesTheSlashText() {
        let block = add(.text, "")
        editor.userTyped("/quo", in: block)
        editor.chooseMenuItem(in: block)
        #expect(block.kind == .quote)
        #expect(block.text.isEmpty)
        #expect(editor.slashMenu == nil)
    }

    @Test func arrowsMoveTheSelectionAndWrap() {
        let block = add(.text, "")
        editor.userTyped("/", in: block)
        editor.moveMenuSelection(by: -1)
        #expect(editor.slashMenu?.selection == BlockKind.allCases.count - 1)
        editor.moveMenuSelection(by: 1)
        editor.moveMenuSelection(by: 1)
        editor.chooseMenuItem(in: block)
        #expect(block.kind == .heading)
    }

    @Test func aSpaceOrNoMatchClosesTheMenu() {
        let block = add(.text, "")
        editor.userTyped("/zzz", in: block)
        #expect(!editor.isMenuOpen(on: block))
        editor.userTyped("/ ", in: block)
        #expect(editor.slashMenu == nil)
    }

    @Test func escapeKeepsTheTextAndStaysClosedUntilItChanges() {
        let block = add(.text, "")
        editor.userTyped("/", in: block)
        editor.dismissMenu()
        #expect(editor.slashMenu == nil)
        #expect(block.text == "/")
        editor.userTyped("/b", in: block)
        #expect(editor.isMenuOpen(on: block))
    }

    @Test func slashInTheMiddleOfALineDoesNothing() {
        let block = add(.text, "")
        editor.userTyped("and/or", in: block)
        #expect(editor.slashMenu == nil)
    }

    @Test func turnIntoKeepsTheTextAndChangesTheKind() {
        let block = add(.text, "Questions")
        editor.openTurnInto(for: block)
        #expect(editor.isMenuOpen(on: block))
        editor.chooseMenuItem(.heading, in: block)
        #expect(block.kind == .heading)
        #expect(block.text == "Questions")
    }

    @Test func choosingDividerFromTheMenuAddsALineBelow() {
        let block = add(.text, "")
        editor.userTyped("/div", in: block)
        editor.chooseMenuItem(in: block)
        #expect(kinds == [.divider, .text])
    }

    // MARK: Make task from a line (#40)

    /// Stand-in for the workspace: makes tasks in the test store.
    private func taskActions(pages: [SchemaList]) -> BlockTaskActions {
        let context = container.mainContext
        return BlockTaskActions(
            taskPages: pages,
            defaultPage: pages.first,
            task: { id in try? context.fetch(FetchDescriptor<SchemaTask>(predicate: #Predicate { $0.id == id })).first },
            makeTask: { title, page in
                let task = SchemaTask(title: title, list: page)
                context.insert(task)
                return task
            },
            toggleTask: { $0.setCompleted(!$0.isCompleted) },
            openTask: { _ in }
        )
    }

    private func todoPage() -> SchemaList {
        let work = SchemaList(title: "Work")
        container.mainContext.insert(work)
        return work
    }

    @Test func makeTaskLinksTheLineAndKeepsIt() throws {
        let work = todoPage()
        let actions = taskActions(pages: [work])
        let line = add(.todo, "Sketch the quick note panel")

        let task = try #require(editor.makeTask(from: line, in: work, actions: actions))
        #expect(task.title == "Sketch the quick note panel")
        #expect(task.list?.id == work.id)
        #expect(line.linkedTaskID == task.id)
        #expect(texts == ["Sketch the quick note panel"])
        #expect(!editor.canMakeTask(from: line, actions: actions))
    }

    @Test func makingATaskFromTextTurnsTheLineIntoAToDo() throws {
        let work = todoPage()
        let line = add(.bullet, "Call the venue")
        editor.makeTask(from: line, in: work, actions: taskActions(pages: [work]))
        #expect(line.kind == .todo)
    }

    @Test func emptyLinesCannotBecomeTasks() {
        let work = todoPage()
        let line = add(.todo, "   ")
        #expect(!editor.canMakeTask(from: line, actions: taskActions(pages: [work])))
        #expect(!editor.canMakeTask(from: add(.text, "No pages"), actions: taskActions(pages: [])))
    }

    @Test func checkingALinkedLineChecksTheTaskAndBack() throws {
        let work = todoPage()
        let actions = taskActions(pages: [work])
        let line = add(.todo, "Book the room")
        let task = try #require(editor.makeTask(from: line, in: work, actions: actions))

        editor.toggleChecked(line, actions: actions)
        #expect(task.isCompleted)
        #expect(editor.isChecked(line, actions: actions))

        task.setCompleted(false)
        #expect(!editor.isChecked(line, actions: actions))
    }

    @Test func makeTasksFromOpenToDosSkipsDoneAndLinkedLines() throws {
        let work = todoPage()
        let actions = taskActions(pages: [work])
        _ = add(.todo, "One")
        let done = add(.todo, "Done already")
        done.isChecked = true
        _ = add(.text, "Plain text")
        let linked = add(.todo, "Linked")
        editor.makeTask(from: linked, in: work, actions: actions)
        _ = add(.todo, "Two")

        #expect(editor.makeTasksFromOpenToDos(in: work, actions: actions) == 2)
        #expect(editor.openToDosWithoutTasks(actions: actions).isEmpty)
    }

    @Test func aDeletedTaskUnlinksTheLine() throws {
        let work = todoPage()
        let actions = taskActions(pages: [work])
        let line = add(.todo, "Gone soon")
        let task = try #require(editor.makeTask(from: line, in: work, actions: actions))
        container.mainContext.delete(task)
        try container.mainContext.save()
        #expect(editor.linkedTask(for: line, actions: actions) == nil)
        #expect(editor.canMakeTask(from: line, actions: actions))
    }
}

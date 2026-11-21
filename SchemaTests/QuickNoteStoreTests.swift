//
//  QuickNoteStoreTests.swift
//  SchemaTests
//
//  Where Quick note (#41) saves notes and tasks.
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct QuickNoteStoreTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let monday = Date(timeIntervalSince1970: 1_794_816_000) // 16 Nov 2026
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    init() throws {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func lists() throws -> [SchemaList] { try context.fetch(FetchDescriptor<SchemaList>()) }

    /// The page's top-level blocks, by TipTap type.
    private func types(_ page: SchemaList) -> [String] {
        (PageDocument.parse(page.documentJSON)?["content"] as? [TipTapDocument.Node] ?? []).compactMap { $0["type"] as? String }
    }

    private func lines(_ page: SchemaList) -> [String] {
        page.documentText.components(separatedBy: "\n")
    }

    @Test func firstNoteMakesIdeasWhenThereIsNoScratchpad() throws {
        context.insert(SchemaList(title: "Work"))
        let page = try #require(QuickNoteStore.saveNote("Call Sam", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar))
        #expect(page.title == "Ideas")
        #expect(page.isScratchpad)
        #expect(types(page) == ["heading", "paragraph"])
        #expect(lines(page).last == "Call Sam")
    }

    /// A note written in the editor (#82) keeps its blocks as they are, without empty lines around it.
    @Test func editorNotesKeepTheirBlocks() throws {
        let ideas = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(ideas)
        let note = #"{"type":"doc","content":[{"type":"paragraph"},{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Milk"}]}]}]},{"type":"paragraph","content":[{"type":"text","text":"See "},{"type":"mention","attrs":{"kind":"page","id":"X","label":"Groceries"}}]},{"type":"paragraph"}]}"#
        try #require(QuickNoteStore.saveNote(documentJSON: note, lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar))
        #expect(types(ideas) == ["heading", "bulletList", "paragraph"])
        #expect(lines(ideas).dropFirst() == ["Milk", "See Groceries"])
    }

    @Test func anEmptyEditorNoteSavesNothing() throws {
        context.insert(SchemaList(title: "Ideas", kind: .scratchpad))
        #expect(QuickNoteStore.saveNote(documentJSON: PageDocument.emptyJSON, lists: try lists(), preferredPageID: nil, context: context) == nil)
    }

    @Test func notesGoUnderTodaysHeadingNewestFirst() throws {
        let ideas = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(ideas)
        ideas.setDocument(TipTapDocument.json(TipTapDocument.document(from: [TipTapDocument.Line(kind: .text, text: "Older note")])))

        QuickNoteStore.saveNote("First", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar)
        QuickNoteStore.saveNote("Second", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar)

        let heading = QuickNoteStore.dateHeading(for: monday, calendar: calendar)
        #expect(lines(ideas) == [heading, "Second", "First", "Older note"])
        #expect(types(ideas) == ["heading", "paragraph", "paragraph", "paragraph"])
    }

    @Test func eachLineBecomesALineWithMarkdown() throws {
        let ideas = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(ideas)
        QuickNoteStore.saveNote("Trip\n- passport\n[] book train\n\n> pack light", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar)
        #expect(types(ideas) == ["heading", "paragraph", "bulletList", "taskList", "blockquote"])
        #expect(Array(lines(ideas).dropFirst()) == ["Trip", "passport", "book train", "pack light"])
    }

    @Test func thePreferredScratchpadWins() throws {
        let ideas = SchemaList(title: "Ideas", order: 1, kind: .scratchpad)
        let meetings = SchemaList(title: "Meetings", order: 2, kind: .scratchpad)
        context.insert(ideas)
        context.insert(meetings)
        let page = QuickNoteStore.saveNote("Agenda", lists: try lists(), preferredPageID: meetings.id, context: context, now: monday, calendar: calendar)
        #expect(page?.id == meetings.id)
        #expect(!ideas.hasDocument)
    }

    @Test func emptyNotesAreNotSaved() throws {
        #expect(QuickNoteStore.saveNote("  \n ", lists: try lists(), preferredPageID: nil, context: context) == nil)
        #expect(try lists().isEmpty)
    }

    @Test func commandReturnSavesATaskInTheDefaultPage() throws {
        let daily = SchemaList(title: "Daily", order: 1)
        let work = SchemaList(title: "Work", order: 2)
        context.insert(daily)
        context.insert(work)
        let task = try #require(QuickNoteStore.saveTask("Book\ndentist", lists: try lists(), allTasks: [], defaultPageID: work.id, context: context))
        #expect(task.title == "Book dentist")
        #expect(task.list?.id == work.id)
    }
}

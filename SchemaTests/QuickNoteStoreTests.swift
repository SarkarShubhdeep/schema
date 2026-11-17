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

    @Test func firstNoteMakesIdeasWhenThereIsNoScratchpad() throws {
        context.insert(SchemaList(title: "Work"))
        let page = try #require(QuickNoteStore.saveNote("Call Sam", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar))
        #expect(page.title == "Ideas")
        #expect(page.isScratchpad)
        #expect(page.orderedBlocks.map(\.kind) == [.heading, .text])
        #expect(page.orderedBlocks.last?.text == "Call Sam")
    }

    @Test func notesGoUnderTodaysHeadingNewestFirst() throws {
        let ideas = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(ideas)
        context.insert(SchemaBlock(text: "Older note", sortIndex: 1, page: ideas))

        QuickNoteStore.saveNote("First", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar)
        QuickNoteStore.saveNote("Second", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar)

        let heading = QuickNoteStore.dateHeading(for: monday, calendar: calendar)
        #expect(ideas.orderedBlocks.map(\.text) == [heading, "Second", "First", "Older note"])
    }

    @Test func eachLineBecomesABlockWithMarkdown() throws {
        let ideas = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(ideas)
        QuickNoteStore.saveNote("Trip\n- passport\n[] book train\n\n> pack light", lists: try lists(), preferredPageID: nil, context: context, now: monday, calendar: calendar)
        #expect(ideas.orderedBlocks.dropFirst().map(\.kind) == [.text, .bullet, .todo, .quote])
        #expect(ideas.orderedBlocks.dropFirst().map(\.text) == ["Trip", "passport", "book train", "pack light"])
    }

    @Test func thePreferredScratchpadWins() throws {
        let ideas = SchemaList(title: "Ideas", order: 1, kind: .scratchpad)
        let meetings = SchemaList(title: "Meetings", order: 2, kind: .scratchpad)
        context.insert(ideas)
        context.insert(meetings)
        let page = QuickNoteStore.saveNote("Agenda", lists: try lists(), preferredPageID: meetings.id, context: context, now: monday, calendar: calendar)
        #expect(page?.id == meetings.id)
        #expect(ideas.blocks.isEmpty)
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

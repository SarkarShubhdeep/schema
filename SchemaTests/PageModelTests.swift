//
//  PageModelTests.swift
//  SchemaTests
//
//  Page types and blocks in an in-memory store (schema V6).
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct PageModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    @Test func newPagesAreToDoListsByDefault() throws {
        let page = SchemaList(title: "Work")
        context.insert(page)
        try context.save()
        #expect(page.pageKind == .todo)
        #expect(!page.isScratchpad)
    }

    @Test func scratchpadKeepsItsKind() throws {
        let page = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(page)
        try context.save()
        let fetched = try #require(try context.fetch(FetchDescriptor<SchemaList>()).first)
        #expect(fetched.pageKind == .scratchpad)
    }

    @Test func unknownStoredKindsFallBack() {
        let page = SchemaList(title: "Later")
        page.pageKindRaw = "board"
        #expect(page.pageKind == .todo)

        let block = SchemaBlock(sortIndex: 1)
        block.kindRaw = "callout"
        #expect(block.kind == .text)
    }

    @Test func blocksComeBackInSortOrder() throws {
        let page = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(page)
        for (text, index) in [("third", 3.0), ("first", 1.0), ("second", 2.0)] {
            context.insert(SchemaBlock(text: text, sortIndex: index, page: page))
        }
        let between = BlockOrdering.index(between: 1, and: 2)
        context.insert(SchemaBlock(kind: .todo, text: "one and a half", sortIndex: between, page: page))
        try context.save()

        #expect(page.orderedBlocks.map(\.text) == ["first", "one and a half", "second", "third"])
    }

    @Test func changingKindClearsWhatTheNewKindCannotHold() {
        let block = SchemaBlock(kind: .todo, text: "Sketch the panel", sortIndex: 1)
        block.isChecked = true

        block.kind = .bullet
        #expect(block.isChecked == false)
        #expect(block.text == "Sketch the panel")

        block.kind = .divider
        #expect(block.text.isEmpty)
    }

    @Test func deletingAPageDeletesItsBlocks() throws {
        let page = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(page)
        context.insert(SchemaBlock(text: "a", sortIndex: 1, page: page))
        context.insert(SchemaBlock(text: "b", sortIndex: 2, page: page))
        try context.save()

        context.delete(page)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SchemaBlock>()) == 0)
    }

    @Test func taskBodyBlocksBelongToTheTaskAndGoWithIt() throws {
        let page = SchemaList(title: "Daily Todos")
        let task = SchemaTask(title: "Call the landlord", list: page)
        context.insert(page)
        context.insert(task)
        context.insert(SchemaBlock(kind: .heading, text: "Before calling", sortIndex: 1, task: task))
        context.insert(SchemaBlock(kind: .todo, text: "Find the lease", sortIndex: 2, task: task))
        try context.save()

        #expect(task.orderedBlocks.map(\.kind) == [.heading, .todo])
        #expect(page.blocks.isEmpty)

        context.delete(task)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SchemaBlock>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SchemaList>()) == 1)
    }
}

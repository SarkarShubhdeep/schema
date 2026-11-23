//
//  TagPagesTests.swift
//  SchemaTests
//
//  Tag pages in a store (#102): the first #tag makes its page; the page
//  gathers tagged lines from scratchpads, task bodies and task titles;
//  ticking, renaming and deleting reach every place the tag is used.
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct TagPagesTests {
    private func store() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private func document(tag id: UUID, label: String = "chores") -> String {
        let chip: [String: Any] = ["type": "mention", "attrs": ["kind": "tag", "id": id.uuidString, "label": label]]
        let doc: [String: Any] = ["type": "doc", "content": [
            ["type": "taskList", "content": [
                ["type": "taskItem", "attrs": ["checked": false], "content": [["type": "paragraph", "content": [["type": "text", "text": "Clean the island "], chip]]]],
            ]],
            ["type": "paragraph", "content": [["type": "text", "text": "Rota "], chip]],
        ]]
        return TipTapDocument.json(doc)
    }

    @Test func theFirstTagMakesItsPageAndGathersItsLines() throws {
        let context = try store()
        let ideas = SchemaList(title: "Ideas", order: 1, kind: .scratchpad)
        let daily = SchemaList(title: "Daily Todos", order: 2)
        let bins = SchemaTask(title: "Take the bins out #chores", list: daily)
        let other = SchemaTask(title: "Call the landlord", list: daily)
        [ideas, daily].forEach(context.insert)
        [bins, other].forEach(context.insert)
        let tagID = UUID()
        ideas.setDocument(document(tag: tagID))

        #expect(TagPages.ensurePages(for: ideas.documentJSON, in: context))
        #expect(!TagPages.ensurePages(for: ideas.documentJSON, in: context))
        let tag = try #require(try context.fetch(FetchDescriptor<SchemaList>()).first { $0.id == tagID })
        #expect(tag.isTagPage && tag.title == "chores")

        let lines = TagPages.lines(for: tag, hideDone: false, in: context)
        #expect(lines.groups.map(\.title) == ["Ideas", "Daily Todos"])
        #expect(lines.groups[0].lines.map(\.text) == ["Clean the island", "Rota"])
        #expect(lines.groups[1].lines.map(\.text) == ["Take the bins out"])
        #expect(lines.openCount == 2)
    }

    @Test func tickingReachesThePageAndTheTask() throws {
        let context = try store()
        let ideas = SchemaList(title: "Ideas", order: 1, kind: .scratchpad)
        let daily = SchemaList(title: "Daily Todos", order: 2)
        let bins = SchemaTask(title: "Bins #chores", list: daily)
        [ideas, daily].forEach(context.insert)
        context.insert(bins)
        let tagID = UUID()
        ideas.setDocument(document(tag: tagID))
        TagPages.ensurePages(for: ideas.documentJSON, in: context)

        TagPages.toggle(holderID: ideas.id, path: [0, 0], isTask: false, checked: true, in: context) { _ in }
        #expect(ideas.checklistDoneCount == 1)
        var toggled: [UUID] = []
        TagPages.toggle(holderID: bins.id, path: [], isTask: true, checked: true, in: context) { toggled.append($0.id) }
        #expect(toggled == [bins.id])
    }

    @Test func renameAndDeleteReachEveryUse() throws {
        let context = try store()
        let ideas = SchemaList(title: "Ideas", order: 1, kind: .scratchpad)
        let daily = SchemaList(title: "Daily Todos", order: 2)
        let bins = SchemaTask(title: "Bins #chores", list: daily)
        [ideas, daily].forEach(context.insert)
        context.insert(bins)
        let tagID = UUID()
        ideas.setDocument(document(tag: tagID))
        TagPages.ensurePages(for: ideas.documentJSON, in: context)
        let tag = try #require(try context.fetch(FetchDescriptor<SchemaList>()).first { $0.id == tagID })

        TagPages.rename(tag, to: "#housework", in: context)
        #expect(tag.title == "housework")
        #expect(ideas.documentText.contains("#housework"))
        #expect(bins.title == "Bins #housework")
        TagPages.rename(tag, to: "two words", in: context) // not a tag name: unchanged
        #expect(tag.title == "housework")

        TagPages.removeEverywhere(tag, in: context)
        #expect(PageTags.tags(in: ideas.documentJSON).isEmpty)
        #expect(ideas.documentText.contains("Rota housework"))
        #expect(bins.title == "Bins housework")
    }
}

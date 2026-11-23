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

    private func synced(_ tag: SchemaList, _ context: ModelContext) throws -> [[String: Any]] {
        let result = TagPages.synced(for: tag, hideDone: false, grouped: true, in: context)
        let payload = try #require(PageDocument.parse(result.json))
        return payload["blocks"] as? [[String: Any]] ?? []
    }

    /// The tag page as the editor would send it back: `blocks` as synced
    /// blocks, with `edit` applied to each one's attrs and line.
    private func tagPageJSON(_ blocks: [[String: Any]], edit: (inout [String: Any], inout [[String: Any]]) -> Void = { _, _ in }) -> String {
        let nodes: [[String: Any]] = blocks.map { block in
            var attrs: [String: Any] = ["holderId": block["holderId"]!, "bid": block["bid"]!, "kind": block["kind"]!, "checked": block["checked"]!]
            var inline = block["content"] as? [[String: Any]] ?? []
            edit(&attrs, &inline)
            return ["type": "syncedBlock", "attrs": attrs, "content": [["type": "paragraph", "content": inline]]]
        }
        return TipTapDocument.json(["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Own words"]]]] + nodes])
    }

    @Test func theFirstTagMakesItsPageAndItsBlocksSync() throws {
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

        let blocks = try synced(tag, context)
        #expect(blocks.map { $0["kind"] as? String } == ["todo", "paragraph", "task"])
        #expect(blocks.map { $0["source"] as? String } == ["Ideas", "Ideas", "Daily Todos"])
        // Ideas' blocks got lasting ids where they live.
        #expect(blocks.prefix(2).allSatisfy { ($0["bid"] as? String).map { ideas.documentJSON.contains($0) } ?? false })
        let summary = TagPages.synced(for: tag, hideDone: false, grouped: true, in: context)
        #expect(summary.openCount == 2 && summary.pageCount == 2)
    }

    @Test func editsOnTheTagPageGoWhereTheBlocksLive() throws {
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
        let blocks = try synced(tag, context)

        var toggled: [UUID] = []
        let edited = tagPageJSON(blocks) { attrs, inline in
            switch attrs["kind"] as? String {
            case "todo":
                attrs["checked"] = true
                inline.insert(["type": "text", "text": "Really "], at: 0)
            case "task":
                attrs["checked"] = true
                inline = [["type": "text", "text": "Bins out tonight #chores"]]
            default: break
            }
        }
        TagPages.writeBack(edited, in: context) { toggled.append($0.id) }
        #expect(ideas.documentText.contains("Really Clean the island #chores"))
        #expect(ideas.checklistDoneCount == 1)
        #expect(bins.title == "Bins out tonight #chores")
        #expect(toggled == [bins.id])
    }

    @Test func returnOnTheTagPageAddsABlockWhereItLives() throws {
        let context = try store()
        let ideas = SchemaList(title: "Ideas", order: 1, kind: .scratchpad)
        context.insert(ideas)
        let tagID = UUID()
        ideas.setDocument(document(tag: tagID))
        TagPages.ensurePages(for: ideas.documentJSON, in: context)
        let tag = try #require(try context.fetch(FetchDescriptor<SchemaList>()).first { $0.id == tagID })
        let todo = try #require(try synced(tag, context).first)
        let chip: [String: Any] = ["type": "mention", "attrs": ["kind": "tag", "id": tagID.uuidString, "label": "chores"]]
        var made = tagPageJSON([todo])
        var doc = try #require(PageDocument.parse(made))
        var content = doc["content"] as! [[String: Any]]
        content.append(["type": "syncedBlock", "attrs": ["holderId": ideas.id.uuidString, "bid": "NEW-1", "kind": "todo", "checked": false, "after": todo["bid"]!],
                        "content": [["type": "paragraph", "content": [["type": "text", "text": "Wipe the fridge "], chip]]]])
        doc["content"] = content
        made = TipTapDocument.json(doc)

        TagPages.writeBack(made, in: context) { _ in }
        #expect(ideas.documentText.contains("Clean the island #chores\nWipe the fridge #chores"))
        #expect(ideas.checklistCount == 2)
        TagPages.writeBack(made, in: context) { _ in } // again: found by its id now, not added twice
        #expect(ideas.checklistCount == 2)
    }

    @Test func removingAndDeletingSyncedBlocks() throws {
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
        let blocks = try synced(tag, context)
        let todoBID = try #require(blocks[0]["bid"] as? String)
        let rotaBID = try #require(blocks[1]["bid"] as? String)

        TagPages.removeTag(tag, from: [(ideas.id, todoBID, "todo"), (bins.id, "task:\(bins.id)", "task")], in: context)
        #expect(ideas.documentText.contains("Clean the island\n"))
        #expect(!ideas.documentText.contains("island #chores"))
        #expect(bins.title == "Bins")
        #expect(try synced(tag, context).count == 1)

        TagPages.deleteEverywhere(holderID: ideas.id, blockID: rotaBID, kind: "paragraph", in: context)
        #expect(!ideas.documentText.contains("Rota"))
        #expect(try synced(tag, context).isEmpty)
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

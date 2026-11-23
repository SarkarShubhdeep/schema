//
//  PageTagsTests.swift
//  SchemaTests
//
//  #tags (#102): finding tagged lines in a document, ticking them from the
//  tag page, and keeping chips and task titles in step with the tag page.
//

import Foundation
import Testing
@testable import Schema

struct PageTagsTests {
    private let chores = UUID()
    private let weekend = UUID()

    private func tag(_ id: UUID, _ label: String) -> [String: Any] {
        ["type": "mention", "attrs": ["kind": "tag", "id": id.uuidString, "label": label]]
    }

    private func text(_ t: String) -> [String: Any] { ["type": "text", "text": t] }

    private func paragraph(_ content: [[String: Any]]) -> [String: Any] { ["type": "paragraph", "content": content] }

    private var document: String {
        let task = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let doc: [String: Any] = ["type": "doc", "content": [
            ["type": "heading", "attrs": ["level": 2], "content": [text("Kitchen "), tag(chores, "chores")]],
            ["type": "taskList", "content": [
                ["type": "taskItem", "attrs": ["checked": false], "content": [paragraph([text("Clean the island "), tag(chores, "chores")])]],
                ["type": "taskItem", "attrs": ["checked": true, "taskId": task.uuidString], "content": [paragraph([text("Fix the porch light "), tag(chores, "chores"), text(" "), tag(weekend, "weekend")])]],
                ["type": "taskItem", "attrs": ["checked": false], "content": [paragraph([text("Not tagged")])]],
            ]],
            ["type": "bulletList", "content": [["type": "listItem", "content": [paragraph([text("Ask for a drill "), tag(weekend, "weekend")])]]]],
            ["type": "orderedList", "attrs": ["start": 1], "content": [["type": "listItem", "content": [paragraph([tag(chores, "chores"), text(" sort recycling")])]]]],
            ["type": "blockquote", "content": [paragraph([text("Rota "), tag(chores, "chores")])]],
            paragraph([text("Plain line")]),
        ]]
        return TipTapDocument.json(doc)
    }

    @Test func findsEveryTaggedLineWithItsKind() {
        let lines = PageTags.lines(taggedWith: chores, in: document)
        #expect(lines.map(\.kind) == [.heading, .todo, .todo, .numbered, .quote])
        #expect(lines.map(\.text) == ["Kitchen", "Clean the island", "Fix the porch light", "sort recycling", "Rota"])
        #expect(lines.map(\.path) == [[0], [1, 0], [1, 1], [3, 0], [4, 0]])
        #expect(lines[2].isChecked)
        #expect(lines[2].taskID?.uuidString == "11111111-1111-1111-1111-111111111111")
        #expect(lines[2].otherTags == ["weekend"])
        #expect(PageTags.lines(taggedWith: weekend, in: document).map(\.kind) == [.todo, .bullet])
        #expect(PageTags.lines(taggedWith: UUID(), in: document).isEmpty)
    }

    @Test func listsTheTagsInADocument() {
        #expect(PageTags.tags(in: document).map(\.label) == ["chores", "weekend"])
        #expect(PageTags.tags(in: PageDocument.emptyJSON).isEmpty)
    }

    @Test func plainTextKeepsTheHash() {
        #expect(PageDocument.summary(of: document).text.hasPrefix("Kitchen #chores\nClean the island #chores"))
    }

    @Test func ticksATaggedToDoByPath() throws {
        let ticked = try #require(PageTags.settingChecked(true, at: [1, 0], in: document))
        #expect(PageTags.lines(taggedWith: chores, in: ticked)[1].isChecked)
        #expect(PageTags.settingChecked(true, at: [0], in: document) == nil) // a heading
        #expect(PageTags.settingChecked(true, at: [9, 9], in: document) == nil)
    }

    @Test func renamesAndRemovesChips() throws {
        let renamed = try #require(PageTags.relabeling(chores, to: "housework", in: document))
        #expect(PageTags.tags(in: renamed).map(\.label) == ["housework", "weekend"])
        #expect(PageTags.relabeling(chores, to: "housework", in: renamed) == nil)

        let removed = try #require(PageTags.removing(chores, in: document))
        #expect(PageTags.tags(in: removed).map(\.label) == ["weekend"])
        #expect(PageDocument.summary(of: removed).text.hasPrefix("Kitchen chores\nClean the island chores"))
    }

    @Test func tagNames() {
        #expect(PageTags.name("#chores") == "chores")
        #expect(PageTags.name("home/garden") == "home/garden")
        #expect(PageTags.name("1st") == nil)
        #expect(PageTags.name("two words") == nil)
        #expect(PageTags.name("") == nil)
    }

    @Test func taskTitlesCarryTagsAsWords() {
        #expect(PageTags.title("Take the bins out #chores", hasTag: "chores"))
        #expect(PageTags.title("#Chores: bins", hasTag: "chores"))
        #expect(!PageTags.title("Take the bins out #choresday", hasTag: "chores"))
        #expect(!PageTags.title("C#chores", hasTag: "chores"))
        #expect(PageTags.renamingTag(in: "Bins #chores today", from: "chores", to: "housework") == "Bins #housework today")
        #expect(PageTags.removingTag(from: "Bins #chores", named: "chores") == "Bins chores")
    }

    @Test func blocksGetLastingIDs() throws {
        let withIDs = try #require(PageTags.ensuringBlockIDs(in: document))
        #expect(PageTags.ensuringBlockIDs(in: withIDs) == nil)
        let lines = PageTags.lines(taggedWith: chores, in: withIDs)
        #expect(lines.allSatisfy { $0.blockID != nil })
        #expect(Set(lines.compactMap(\.blockID)).count == lines.count)
        let todo = try #require(lines.first { $0.kind == .todo })
        #expect(PageTags.path(ofBlock: try #require(todo.blockID), in: withIDs) == [1, 0])
        #expect(lines.first { $0.kind == .numbered }?.number == 1)
    }

    @Test func syncedBlocksOnATagPageAreNotItsOwnTaggedLines() {
        let synced: [String: Any] = ["type": "syncedBlock", "attrs": ["bid": "X"], "content": [paragraph([text("Elsewhere "), tag(chores, "chores")])]]
        let json = TipTapDocument.json(["type": "doc", "content": [synced]])
        #expect(PageTags.lines(taggedWith: chores, in: json).isEmpty)
    }

    @Test func writingABlockBack() throws {
        let withIDs = try #require(PageTags.ensuringBlockIDs(in: document))
        let lines = PageTags.lines(taggedWith: chores, in: withIDs)
        let todo = try #require(lines.first { $0.kind == .todo }?.blockID)
        let updated = try #require(PageTags.updating(block: todo, inline: [text("Scrub the island "), tag(chores, "chores")], checked: true, in: withIDs))
        let after = PageTags.lines(taggedWith: chores, in: updated)
        #expect(after[1].text == "Scrub the island" && after[1].isChecked)
        #expect(PageTags.updating(block: todo, inline: [text("Scrub the island "), tag(chores, "chores")], checked: true, in: updated) == nil)

        let inserted = try #require(PageTags.inserting(after: todo, kind: .todo, blockID: "NEW", inline: [text("Wipe the fridge "), tag(chores, "chores")], in: updated))
        #expect(PageTags.lines(taggedWith: chores, in: inserted).map(\.text).contains("Wipe the fridge"))
        #expect(PageTags.path(ofBlock: "NEW", in: inserted) == [1, 1])

        let untagged = try #require(PageTags.removing(chores, fromBlock: "NEW", in: inserted))
        #expect(!PageTags.lines(taggedWith: chores, in: untagged).map(\.text).contains("Wipe the fridge"))
        #expect(PageTags.path(ofBlock: "NEW", in: untagged) == [1, 1]) // words left: the block stays

        let deleted = try #require(PageTags.deleting(block: "NEW", in: untagged))
        #expect(PageTags.path(ofBlock: "NEW", in: deleted) == nil)
    }
}

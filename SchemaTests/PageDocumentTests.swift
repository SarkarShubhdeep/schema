//
//  PageDocumentTests.swift
//  SchemaTests
//
//  Reading and changing page documents in Swift (#77): plain text, to-dos
//  and their tasks, the editor's own JSON, and Quick note.
//

import Foundation
import Testing
@testable import Schema

struct PageDocumentTests {
    private typealias Line = TipTapDocument.Line
    private let taskID = UUID()

    private func json(_ lines: [Line]) -> String {
        TipTapDocument.json(TipTapDocument.document(from: lines))
    }

    @Test func summaryHasTextToDosAndLinks() {
        let doc = json([
            Line(kind: .heading, text: "Plan"),
            Line(kind: .text, text: "One\nTwo"),
            Line(kind: .todo, text: "Linked", isChecked: true, taskID: taskID),
            Line(kind: .todo, text: "Open"),
            Line(kind: .divider, text: ""),
        ])
        let summary = PageDocument.summary(of: doc)
        #expect(summary.text == "Plan\nOne\nTwo\nLinked\nOpen")
        #expect(summary.linkedTaskIDs == [taskID])
        #expect(summary.checklistCount == 2)
        #expect(summary.checklistDoneCount == 1)
    }

    /// A mention (#81) reads as its name, in search and in Markdown.
    @Test func mentionsReadAsTheirNames() {
        let doc = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"See "},{"type":"mention","attrs":{"kind":"page","id":"\#(taskID.uuidString)","label":"Ideas"}},{"type":"text","text":" on "},{"type":"mention","attrs":{"kind":"date","id":"2026-11-21","label":"Sat 21 Nov"}}]}]}"#
        #expect(PageDocument.summary(of: doc).text == "See Ideas on Sat 21 Nov")
        #expect(PageMarkdown.markdown(fromJSON: doc) == "See Ideas on Sat 21 Nov\n")
    }

    /// The editor sends `taskId: null` on to-dos without a task.
    @Test func readsTheEditorsOwnJSON() {
        let fromEditor = #"{"type":"doc","content":[{"type":"taskList","content":[{"type":"taskItem","attrs":{"checked":false,"taskId":null},"content":[{"type":"paragraph","content":[{"type":"text","text":"Plain"}]}]},{"type":"taskItem","attrs":{"checked":true,"taskId":"\#(taskID.uuidString)"},"content":[{"type":"paragraph","content":[{"type":"text","text":"Made"}]}]}]}]}"#
        let summary = PageDocument.summary(of: fromEditor)
        #expect(summary.linkedTaskIDs == [taskID])
        #expect(summary.checklistDoneCount == 1)
        #expect(PageDocument.openToDosWithoutTasks(in: fromEditor).map(\.text) == ["Plain"])
    }

    @Test func linkedToDosFollowTheirTasks() {
        let doc = json([Line(kind: .todo, text: "Linked", taskID: taskID), Line(kind: .todo, text: "Open")])
        // Nothing to change: the very same text comes back, so the editor isn't reloaded.
        #expect(PageDocument.applyingTaskStates(to: doc) { _ in false } == doc)
        let ticked = PageDocument.applyingTaskStates(to: doc) { $0 == taskID ? true : nil }
        #expect(PageDocument.summary(of: ticked).checklistDoneCount == 1)
        // A deleted task leaves its line alone.
        #expect(PageDocument.applyingTaskStates(to: doc) { _ in nil } == doc)
    }

    @Test func tickingALinkedToDoTogglesItsTask() {
        let doc = json([Line(kind: .todo, text: "Linked", isChecked: true, taskID: taskID)])
        #expect(PageDocument.tasksToToggle(in: doc) { _ in false } == [taskID])
        #expect(PageDocument.tasksToToggle(in: doc) { _ in true }.isEmpty)
        #expect(PageDocument.tasksToToggle(in: doc) { _ in nil }.isEmpty)
    }

    @Test func openToDosBecomeLinkedTasks() {
        let doc = json([
            Line(kind: .todo, text: "Write it"),
            Line(kind: .todo, text: "Done already", isChecked: true),
            Line(kind: .todo, text: "  "),
            Line(kind: .todo, text: "Has one", taskID: taskID),
        ])
        var titles: [String] = []
        let result = PageDocument.linkingOpenToDos(in: doc) { titles.append($0); return UUID() }
        #expect(titles == ["Write it"])
        #expect(result.made == 1)
        #expect(PageDocument.summary(of: result.json).linkedTaskIDs.count == 2)
        #expect(PageDocument.openToDosWithoutTasks(in: result.json).isEmpty)
    }

    @Test func quickNotesGoUnderTodaysHeading() {
        let today = "Monday, 16 November"
        let first = PageDocument.prependingNote([Line(kind: .text, text: "First")], under: today, to: PageDocument.emptyJSON)
        #expect(PageDocument.summary(of: first).text == "\(today)\nFirst")
        let second = PageDocument.prependingNote([Line(kind: .bullet, text: "Second")], under: today, to: first)
        #expect(PageDocument.summary(of: second).text == "\(today)\nSecond\nFirst")
        let tomorrow = PageDocument.prependingNote([Line(kind: .text, text: "Next")], under: "Tuesday, 17 November", to: second)
        #expect(PageDocument.summary(of: tomorrow).text == "Tuesday, 17 November\nNext\n\(today)\nSecond\nFirst")
    }
}

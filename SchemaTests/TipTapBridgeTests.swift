//
//  TipTapBridgeTests.swift
//  SchemaTests
//
//  The editor bridge (#76) against a fake page: it waits for "ready", never
//  sends the same document twice, does not echo the editor's own changes,
//  and passes Esc, focus and errors through.
//

import Foundation
import Testing
@testable import Schema

@MainActor
private final class FakePage: EditorScriptRunner {
    var scripts: [(String, [String: Any])] = []
    func run(_ script: String, arguments: [String: Any]) { scripts.append((script, arguments)) }
    var setContentCount: Int { scripts.filter { $0.0.contains("setContent") }.count }
}

@MainActor
struct TipTapBridgeTests {
    private let page = FakePage()
    private let bridge = TipTapBridge()

    init() { bridge.runner = page }

    @Test func holdsTheDocumentUntilTheEditorIsReady() {
        bridge.show(#"{"type":"doc"}"#, key: "A")
        #expect(page.scripts.isEmpty)
        bridge.receive(["type": "ready"])
        #expect(page.setContentCount == 1)
        #expect(page.scripts.first?.1["json"] as? String == #"{"type":"doc"}"#)
    }

    @Test func sendsEachDocumentOnce() {
        bridge.receive(["type": "ready"])
        bridge.show("A", key: "page")
        bridge.show("A", key: "page")
        #expect(page.setContentCount == 1)
        bridge.show("B", key: "page")
        #expect(page.setContentCount == 2)
    }

    @Test func doesNotEchoTheEditorsOwnChanges() {
        var changes: [String] = []
        bridge.onChange = { json, _ in changes.append(json) }
        bridge.receive(["type": "ready"])
        bridge.show(#"{"type":"doc"}"#, key: "A")

        let edited: [String: Any] = ["type": "doc", "content": [["type": "paragraph"]]]
        bridge.receive(["type": "change", "key": "A", "json": edited])
        let editedText = TipTapBridge.jsonText(edited)!
        #expect(changes == [editedText])

        // SwiftUI hands the saved change straight back: nothing is re-sent.
        bridge.show(editedText, key: "A")
        #expect(page.setContentCount == 1)
    }

    @Test func anotherPageWithTheSameDocumentIsStillSent() {
        bridge.receive(["type": "ready"])
        bridge.show(#"{"type":"doc"}"#, key: "A")
        bridge.show(#"{"type":"doc"}"#, key: "B")
        #expect(page.setContentCount == 2)
        #expect(page.scripts.last?.1["key"] as? String == "B")
    }

    @Test func aLateChangeFromThePreviousPageKeepsItsKey() {
        var saved: [(String, String)] = []
        bridge.onChange = { saved.append(($0, $1)) }
        bridge.receive(["type": "ready"])
        bridge.show(#"{"type":"doc"}"#, key: "A")
        bridge.show(#"{"type":"doc","x":1}"#, key: "B")
        bridge.receive(["type": "change", "key": "A", "json": ["type": "doc", "content": []]])
        #expect(saved.map(\.1) == ["A"])
        // Page B is still what the editor shows: nothing is re-sent.
        bridge.show(#"{"type":"doc","x":1}"#, key: "B")
        #expect(page.setContentCount == 2)
    }

    @Test func focusRequestsRunOncePerToken() {
        bridge.receive(["type": "ready"])
        let request = EditorFocusRequest(position: .start)
        bridge.focus(request)
        bridge.focus(request)
        #expect(page.scripts.filter { $0.0.contains("focus") }.count == 1)
        #expect(page.scripts.last?.1["position"] as? String == "start")
        bridge.focus(EditorFocusRequest(position: .end))
        #expect(page.scripts.filter { $0.0.contains("focus") }.count == 2)
    }

    @Test func aReloadedPageGetsTheDocumentAgain() {
        bridge.receive(["type": "ready"])
        bridge.show("A", key: "page")
        bridge.pageDidReset()
        bridge.receive(["type": "ready"])
        #expect(page.setContentCount == 2)
    }

    @Test func passesEscapeFocusAndErrorsThrough() {
        var escaped = false
        var focused: Bool?
        var error: String?
        bridge.onEscape = { escaped = true }
        bridge.onFocusChange = { focused = $0 }
        bridge.onError = { error = $0 }
        bridge.receive(["type": "escape"])
        bridge.receive(["type": "focus", "focused": true])
        bridge.receive(["type": "error", "message": "boom", "source": "editor.js:1"])
        #expect(escaped)
        #expect(focused == true)
        #expect(error?.contains("boom") == true)
    }

    @Test func copyMarkdownPassesTheBlockAlong() {
        var copied: String?
        bridge.onCopyMarkdown = { copied = $0 }
        let block: [String: Any] = ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Hi"]]]]]
        bridge.receive(["type": "copyMarkdown", "json": block])
        #expect(copied.map { PageMarkdown.markdown(fromJSON: $0) } == "Hi\n")
    }

    @Test func makeTaskLinksTheLineToTheNewTask() {
        bridge.receive(["type": "ready"])
        let page = UUID()
        let task = UUID()
        var asked: (String, UUID)?
        bridge.onMakeTask = { text, pageID in
            asked = (text, pageID)
            return task
        }
        bridge.receive(["type": "makeTask", "ref": "REF", "text": "Call the bank", "pageId": page.uuidString])
        #expect(asked?.0 == "Call the bank" && asked?.1 == page)
        let link = self.page.scripts.last
        #expect(link?.0.contains("linkTask") == true)
        #expect(link?.1["ref"] as? String == "REF")
        #expect(link?.1["taskId"] as? String == task.uuidString)
    }

    @Test func makeTaskThatFailsUnlinksTheLine() {
        bridge.receive(["type": "ready"])
        bridge.onMakeTask = { _, _ in nil }
        bridge.receive(["type": "makeTask", "ref": "REF", "text": "x", "pageId": UUID().uuidString])
        #expect(page.scripts.last?.1["taskId"] is NSNull)
    }

    @Test func taskContextIsSentOnceReadyAndOnlyWhenItChanges() {
        var context = EditorTaskContext()
        context.pages = [.init(id: "A", title: "Work", isDefault: true)]
        bridge.setTaskContext(context.json)
        #expect(page.scripts.isEmpty)
        bridge.receive(["type": "ready"])
        bridge.setTaskContext(context.json)
        #expect(page.scripts.filter { $0.0.contains("setTaskContext") }.count == 1)
        context.tasks["T"] = .init(page: "Work", pageId: "A")
        bridge.setTaskContext(context.json)
        #expect(page.scripts.filter { $0.0.contains("setTaskContext") }.count == 2)
        #expect((page.scripts.last?.1["json"] as? String)?.contains(#""T":{"page":"Work","pageId":"A"}"#) == true)
    }

    @Test func openTaskAndChangeDefaultPagePassAlong() {
        let id = UUID()
        var opened: UUID?
        var changed = false
        bridge.onOpenTask = { opened = $0 }
        bridge.onChangeDefaultPage = { changed = true }
        bridge.receive(["type": "openTask", "taskId": id.uuidString])
        bridge.receive(["type": "changeDefaultPage"])
        #expect(opened == id && changed)
        let page = UUID()
        var moved: (UUID, UUID)?
        bridge.onMoveTask = { moved = ($0, $1) }
        bridge.receive(["type": "moveTask", "taskId": id.uuidString, "pageId": page.uuidString])
        #expect(moved?.0 == id && moved?.1 == page)
    }

    @Test func mentionContextIsSentAndChipsOpenWhatTheyPointTo() {
        bridge.receive(["type": "ready"])
        var context = EditorMentionContext()
        context.pages = [.init(id: "P", title: "Ideas", kind: "scratchpad")]
        bridge.setMentionContext(context.json)
        bridge.setMentionContext(context.json)
        #expect(page.scripts.filter { $0.0.contains("setMentionContext") }.count == 1)

        var opened: [EditorMention] = []
        bridge.onOpenMention = { opened.append($0) }
        let id = UUID()
        bridge.receive(["type": "openMention", "kind": "page", "id": id.uuidString])
        bridge.receive(["type": "openMention", "kind": "task", "id": id.uuidString])
        bridge.receive(["type": "openMention", "kind": "page", "id": "not an id"])
        #expect(opened == [.page(id), .task(id)])
    }

    @Test func dateAndTimeMentionsReadBack() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = EditorMention(kind: "date", id: "2026-11-21", calendar: calendar)
        #expect(day == .date(Date(timeIntervalSince1970: 1_795_219_200)))
        #expect(EditorMention(kind: "time", id: "2026-11-21T16:12:00.000Z") == .date(Date(timeIntervalSince1970: 1_795_219_200 + 16 * 3600 + 12 * 60)))
        #expect(EditorMention(kind: "date", id: "21 Nov") == nil)
    }

    @Test func snippetsAreSentOnlyWhenTheyChange() {
        bridge.receive(["type": "ready"])
        let json = SnippetStore.encode([Snippet(trigger: ";email", text: "name@example.com")])
        bridge.setSnippets(json)
        bridge.setSnippets(json)
        bridge.setSnippets("[]")
        let calls = page.scripts.filter { $0.0.contains("setSnippets") }.map { $0.1["json"] as? String }
        #expect(calls == [json, "[]"])
    }

    @Test func typographyIsSentOnlyWhenItChanges() {
        bridge.receive(["type": "ready"])
        bridge.setTypography(true)
        bridge.setTypography(true)
        bridge.setTypography(false)
        let calls = page.scripts.filter { $0.0.contains("setTypography") }.map { $0.1["json"] as? String }
        #expect(calls == ["true", "false"])
    }

    @Test func quickNoteModeIsSentAndReturnSubmitsTheNote() {
        bridge.receive(["type": "ready"])
        bridge.setMode(.note)
        bridge.setMode(.note)
        let modes = page.scripts.filter { $0.0.contains("setMode") }
        #expect(modes.count == 1)
        #expect(modes.first?.1["json"] as? String == #""note""#)

        var saved: (String, Bool)?
        bridge.onSubmit = { saved = ($0, $1) }
        let note: [String: Any] = ["type": "doc", "content": [["type": "paragraph", "content": [["type": "text", "text": "Hi"]]]]]
        bridge.receive(["type": "submit", "asTask": true, "json": note])
        #expect(saved.map { PageDocument.summary(of: $0.0).text } == "Hi")
        #expect(saved?.1 == true)
    }

    @Test func rightClickEditCommandsPassAlong() {
        var commands: [EditorEditCommand] = []
        bridge.onEditCommand = { commands.append($0) }
        for command in ["cut", "copy", "paste", "selectAll"] {
            bridge.receive(["type": "editCommand", "command": command])
        }
        #expect(commands == [.cut, .copy, .paste])
    }
}

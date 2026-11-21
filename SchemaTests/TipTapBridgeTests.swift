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
}

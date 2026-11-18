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
        bridge.show(#"{"type":"doc"}"#)
        #expect(page.scripts.isEmpty)
        bridge.receive(["type": "ready"])
        #expect(page.setContentCount == 1)
        #expect(page.scripts.first?.1["json"] as? String == #"{"type":"doc"}"#)
    }

    @Test func sendsEachDocumentOnce() {
        bridge.receive(["type": "ready"])
        bridge.show("A")
        bridge.show("A")
        #expect(page.setContentCount == 1)
        bridge.show("B")
        #expect(page.setContentCount == 2)
    }

    @Test func doesNotEchoTheEditorsOwnChanges() {
        var changes: [String] = []
        bridge.onChange = { changes.append($0) }
        bridge.receive(["type": "ready"])
        bridge.show(#"{"type":"doc"}"#)

        let edited: [String: Any] = ["type": "doc", "content": [["type": "paragraph"]]]
        bridge.receive(["type": "change", "json": edited])
        let editedText = TipTapBridge.jsonText(edited)!
        #expect(changes == [editedText])

        // SwiftUI hands the saved change straight back: nothing is re-sent.
        bridge.show(editedText)
        #expect(page.setContentCount == 1)
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
        bridge.show("A")
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
}

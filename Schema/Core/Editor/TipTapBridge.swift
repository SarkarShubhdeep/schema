//
//  TipTapBridge.swift
//  Schema
//
//  The Swift half of the editor bridge (#76), kept apart from WKWebView so
//  it can be tested with a fake. It holds the document until the editor
//  says it is ready, never sends the same document twice, and does not echo
//  the editor's own changes back to it.
//

import Foundation

/// Runs a script in the editor page. WKWebView in the app, a fake in tests.
@MainActor
protocol EditorScriptRunner: AnyObject {
    func run(_ script: String, arguments: [String: Any])
}

/// Where the caret goes when Swift moves focus into the editor.
enum EditorFocusPosition: String, Sendable {
    case start
    case end
}

/// Asks the editor to take focus. A new token asks again, even for the same position.
struct EditorFocusRequest: Equatable, Sendable {
    var position: EditorFocusPosition
    var token = UUID()
}

@MainActor
final class TipTapBridge {
    weak var runner: (any EditorScriptRunner)?

    var onChange: ((String) -> Void)?
    var onEscape: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    /// How long the editor took to show a document, in milliseconds.
    var onLoaded: ((Double) -> Void)?

    private(set) var isReady = false
    /// The document the editor shows now, as far as Swift knows.
    private(set) var shownJSON: String?
    private var wantedJSON: String?
    private var pendingFocus: EditorFocusRequest?
    private var lastFocus: EditorFocusRequest?

    /// Show this document (TipTap JSON text). Sent once the editor is ready.
    func show(_ json: String) {
        wantedJSON = json
        flush()
    }

    func focus(_ request: EditorFocusRequest?) {
        guard let request, request != lastFocus else { return }
        pendingFocus = request
        flush()
    }

    /// A message from the page: `{ type, ... }`.
    func receive(_ body: [String: Any]) {
        guard let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            isReady = true
            flush()
        case "change":
            guard let json = Self.jsonText(body["json"]) else { return }
            shownJSON = json
            wantedJSON = json
            onChange?(json)
        case "loaded":
            onLoaded?((body["ms"] as? Double) ?? 0)
        case "escape":
            onEscape?()
        case "focus":
            onFocusChange?((body["focused"] as? Bool) ?? false)
        case "error":
            onError?("\(body["message"] ?? "") \(body["source"] ?? "")")
        default:
            break
        }
    }

    /// The page went away (its process ended): wait for a new "ready", then send the document again.
    func pageDidReset() {
        isReady = false
        shownJSON = nil
    }

    private func flush() {
        guard isReady, let runner else { return }
        if let wantedJSON, wantedJSON != shownJSON {
            shownJSON = wantedJSON
            runner.run("window.schemaEditor.setContent(JSON.parse(json))", arguments: ["json": wantedJSON])
        }
        if let pendingFocus {
            lastFocus = pendingFocus
            self.pendingFocus = nil
            runner.run("window.schemaEditor.focus(position)", arguments: ["position": pendingFocus.position.rawValue])
        }
    }

    static func jsonText(_ object: Any?) -> String? {
        guard let object, JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

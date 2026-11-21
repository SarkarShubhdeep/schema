//
//  TipTapBridge.swift
//  Schema
//
//  The Swift half of the editor bridge (#76), kept apart from WKWebView so
//  it can be tested with a fake. It holds the document until the editor
//  says it is ready, never sends the same document twice, and does not echo
//  the editor's own changes back to it. Each document has a key (the page
//  or task it belongs to); a change comes back with the key it was made
//  in, so one still pending when the page switches is saved to its page.
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

    /// The document changed: its JSON text and its key.
    var onChange: ((_ json: String, _ key: String) -> Void)?
    var onEscape: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?
    /// How long the editor took to show a document, in milliseconds.
    var onLoaded: ((Double) -> Void)?
    /// Copy as Markdown from a block's menu (#79): the block as a TipTap document.
    var onCopyMarkdown: ((_ json: String) -> Void)?
    /// Make task in … on a to-do (#80): the line's text and the page. Returns
    /// the new task's id, which the line is then linked to; nil if none was made.
    var onMakeTask: ((_ text: String, _ pageID: UUID) -> UUID?)?
    /// "Task in …" on a linked to-do.
    var onOpenTask: ((UUID) -> Void)?
    /// "Change the default page…" in Make task in.
    var onChangeDefaultPage: (() -> Void)?

    private(set) var isReady = false
    /// The document the editor shows now, as far as Swift knows.
    private(set) var shownJSON: String?
    private(set) var shownKey: String?
    private var wantedJSON: String?
    private var wantedKey: String?
    private var pendingFocus: EditorFocusRequest?
    private var wantedTaskContext: String?
    private var shownTaskContext: String?
    private var lastFocus: EditorFocusRequest?

    /// Show this document (TipTap JSON text) for `key`. Sent once the editor is ready.
    func show(_ json: String, key: String) {
        wantedJSON = json
        wantedKey = key
        flush()
    }

    /// The to-do pages a line can become a task in and the tasks lines are
    /// linked to, as JSON text (see `EditorTaskContext`). Sent when it changes.
    func setTaskContext(_ json: String) {
        wantedTaskContext = json
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
            guard let json = Self.jsonText(body["json"]), let key = body["key"] as? String else { return }
            if key == shownKey {
                shownJSON = json
                if key == wantedKey { wantedJSON = json }
            }
            onChange?(json, key)
        case "loaded":
            onLoaded?((body["ms"] as? Double) ?? 0)
        case "escape":
            onEscape?()
        case "focus":
            onFocusChange?((body["focused"] as? Bool) ?? false)
        case "copyMarkdown":
            guard let json = Self.jsonText(body["json"]) else { return }
            onCopyMarkdown?(json)
        case "makeTask":
            guard let ref = body["ref"] as? String,
                  let text = body["text"] as? String,
                  let pageID = (body["pageId"] as? String).flatMap(UUID.init(uuidString:)) else { return }
            let taskID = onMakeTask?(text, pageID)
            guard isReady, let runner else { return }
            runner.run("window.schemaEditor.linkTask(ref, taskId)", arguments: ["ref": ref, "taskId": taskID?.uuidString ?? NSNull()])
        case "openTask":
            guard let id = (body["taskId"] as? String).flatMap(UUID.init(uuidString:)) else { return }
            onOpenTask?(id)
        case "changeDefaultPage":
            onChangeDefaultPage?()
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
        shownKey = nil
        shownTaskContext = nil
    }

    private func flush() {
        guard isReady, let runner else { return }
        if let wantedJSON, let wantedKey, wantedJSON != shownJSON || wantedKey != shownKey {
            shownJSON = wantedJSON
            shownKey = wantedKey
            runner.run("window.schemaEditor.setContent(JSON.parse(json), key)", arguments: ["json": wantedJSON, "key": wantedKey])
        }
        if let wantedTaskContext, wantedTaskContext != shownTaskContext {
            shownTaskContext = wantedTaskContext
            runner.run("window.schemaEditor.setTaskContext(JSON.parse(json))", arguments: ["json": wantedTaskContext])
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

/// What the editor needs to offer Make task in … and show Task in … (#80).
struct EditorTaskContext: Encodable, Equatable {
    struct Page: Encodable, Equatable {
        var id: String
        var title: String
        var isDefault: Bool
    }

    struct Task: Encodable, Equatable {
        var page: String
    }

    var pages: [Page] = []
    var tasks: [String: Task] = [:]

    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? #"{"pages":[],"tasks":{}}"#
    }
}

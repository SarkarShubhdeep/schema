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

/// Clipboard commands the editor's right-click menu asks the app to run.
enum EditorEditCommand: String, Sendable {
    case cut
    case copy
    case paste
}

/// How the editor behaves: a page, or Quick note's note (#82).
enum EditorMode: String, Sendable {
    case page
    case note
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
    /// Move task to … on a linked to-do: the task and the page.
    var onMoveTask: ((_ taskID: UUID, _ pageID: UUID) -> Void)?
    /// Cut, Copy or Paste from the editor's right-click menu (#83).
    var onEditCommand: ((EditorEditCommand) -> Void)?
    /// Quick note (#82): Return saves the note (its JSON text); asTask for ⌘Return.
    var onSubmit: ((_ json: String, _ asTask: Bool) -> Void)?
    /// A mention chip was clicked (#81).
    var onOpenMention: ((EditorMention) -> Void)?
    /// "Change the default page…" in Make task in.
    var onChangeDefaultPage: (() -> Void)?

    private(set) var isReady = false
    /// The document the editor shows now, as far as Swift knows.
    private(set) var shownJSON: String?
    private(set) var shownKey: String?
    private var wantedJSON: String?
    private var wantedKey: String?
    private var pendingFocus: EditorFocusRequest?
    /// Context sent with a `schemaEditor` method (setTaskContext,
    /// setMentionContext): what Swift wants shown and what was last sent.
    private var wantedContexts: [String: String] = [:]
    private var shownContexts: [String: String] = [:]
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
        wantedContexts["setTaskContext"] = json
        flush()
    }

    /// The pages and open tasks @ can mention (#81), as JSON text (see
    /// `EditorMentionContext`). Sent when it changes.
    func setMentionContext(_ json: String) {
        wantedContexts["setMentionContext"] = json
        flush()
    }

    /// Replacements as you type, like -> to → (#99), from Settings.
    func setTypography(_ isOn: Bool) {
        wantedContexts["setTypography"] = isOn ? "true" : "false"
        flush()
    }

    /// Your snippets (#101), as the JSON Settings stores. Sent when they change.
    func setSnippets(_ json: String) {
        wantedContexts["setSnippets"] = json
        flush()
    }

    /// A page, or Quick note's small note where Return saves (#82).
    func setMode(_ mode: EditorMode) {
        wantedContexts["setMode"] = "\"\(mode.rawValue)\""
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
        case "moveTask":
            guard let taskID = (body["taskId"] as? String).flatMap(UUID.init(uuidString:)),
                  let pageID = (body["pageId"] as? String).flatMap(UUID.init(uuidString:)) else { return }
            onMoveTask?(taskID, pageID)
        case "editCommand":
            guard let command = (body["command"] as? String).flatMap(EditorEditCommand.init(rawValue:)) else { return }
            onEditCommand?(command)
        case "submit":
            guard let json = Self.jsonText(body["json"]) else { return }
            onSubmit?(json, (body["asTask"] as? Bool) ?? false)
        case "openMention":
            guard let mention = EditorMention(kind: body["kind"] as? String, id: body["id"] as? String) else { return }
            onOpenMention?(mention)
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
        shownContexts = [:]
    }

    private func flush() {
        guard isReady, let runner else { return }
        if let wantedJSON, let wantedKey, wantedJSON != shownJSON || wantedKey != shownKey {
            shownJSON = wantedJSON
            shownKey = wantedKey
            runner.run("window.schemaEditor.setContent(JSON.parse(json), key)", arguments: ["json": wantedJSON, "key": wantedKey])
        }
        for (method, json) in wantedContexts.sorted(by: { $0.key < $1.key }) where shownContexts[method] != json {
            shownContexts[method] = json
            runner.run("window.schemaEditor.\(method)(JSON.parse(json))", arguments: ["json": json])
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
        var pageId: String
    }

    var pages: [Page] = []
    var tasks: [String: Task] = [:]

    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? #"{"pages":[],"tasks":{}}"#
    }
}

/// What @ can mention (#81): every page and the open tasks.
struct EditorMentionContext: Encodable, Equatable {
    struct Page: Encodable, Equatable {
        var id: String
        var title: String
        var kind: String
    }

    struct Task: Encodable, Equatable {
        var id: String
        var title: String
        var page: String
    }

    var pages: [Page] = []
    var tasks: [Task] = []

    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? #"{"pages":[],"tasks":[]}"#
    }
}

/// A clicked mention chip (#81): what it points to.
enum EditorMention: Equatable {
    case page(UUID)
    case task(UUID)
    /// A day (@today, @tomorrow) or a moment (@now), at local midnight or the exact time.
    case date(Date)

    init?(kind: String?, id: String?, calendar: Calendar = .current) {
        guard let id else { return nil }
        switch kind {
        case "page":
            guard let uuid = UUID(uuidString: id) else { return nil }
            self = .page(uuid)
        case "task":
            guard let uuid = UUID(uuidString: id) else { return nil }
            self = .task(uuid)
        case "date":
            let parts = id.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                  let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
            self = .date(day)
        case "time":
            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = parser.date(from: id) ?? ISO8601DateFormatter().date(from: id) else { return nil }
            self = .date(date)
        default:
            return nil
        }
    }
}

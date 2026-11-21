//
//  TipTapEditorView.swift
//  Schema
//
//  The TipTap editor (#76) in a WKWebView. Everything it loads comes from
//  the app bundle (Resources/Editor); the page's content-security policy
//  blocks the network. The sandbox still needs outgoing connections, or the
//  web process cannot start at all. TipTapBridge does the talking; this
//  view only hosts the page and passes messages through.
//

import OSLog
import SwiftUI
import WebKit

struct TipTapEditorView: NSViewRepresentable {
    /// The document to show, as TipTap JSON text.
    let documentJSON: String
    /// The page or task the document belongs to.
    let documentKey: String
    var focusRequest: EditorFocusRequest?
    /// The document changed: its JSON text and the key it belongs to, which
    /// can be the previous page's for a change made just before switching.
    var onChange: ((_ json: String, _ key: String) -> Void)?
    var onEscape: (() -> Void)?
    /// Make task in … and Task in … on to-dos (#80); nil where lines cannot become tasks.
    var taskContextJSON: String?
    var onMakeTask: ((_ text: String, _ pageID: UUID) -> UUID?)?
    var onOpenTask: ((UUID) -> Void)?
    var onMoveTask: ((_ taskID: UUID, _ pageID: UUID) -> Void)?
    var onChangeDefaultPage: (() -> Void)?
    /// Quick note's note, where Return saves (#82).
    var mode: EditorMode = .page
    var onSubmit: ((_ json: String, _ asTask: Bool) -> Void)?
    /// What @ can mention, and opening a clicked chip (#81).
    var mentionContextJSON: String?
    var onOpenMention: ((EditorMention) -> Void)?

    static let log = Logger(subsystem: "com.sarkarshubhdeep.schema", category: "Editor")

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(WeakMessageHandler(context.coordinator), name: "schema")
        configuration.suppressesIncrementalRendering = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.navigationDelegate = context.coordinator
        #if DEBUG
        webView.isInspectable = true
        #endif
        context.coordinator.attach(webView)
        context.coordinator.update(from: self)

        if let page = Bundle.main.url(forResource: "editor", withExtension: "html"),
           let resources = Bundle.main.resourceURL {
            webView.loadFileURL(page, allowingReadAccessTo: resources)
        } else {
            Self.log.error("Editor files are missing from the app bundle")
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(from: self)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "schema")
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, EditorScriptRunner {
        let bridge = TipTapBridge()
        private weak var webView: WKWebView?
        private var onEscape: (() -> Void)?

        func attach(_ webView: WKWebView) {
            self.webView = webView
            bridge.runner = self
            bridge.onEscape = { [weak self] in
                // Hand the keyboard back to the app, then let the page react.
                self?.webView?.window?.makeFirstResponder(nil)
                self?.onEscape?()
            }
            bridge.onError = { TipTapEditorView.log.error("Editor script error: \($0, privacy: .public)") }
            bridge.onCopyMarkdown = { json in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(PageMarkdown.markdown(fromJSON: json), forType: .string)
            }
            bridge.onLoaded = { [weak self] in
                TipTapEditorView.log.info("Editor showed a document in \($0, format: .fixed(precision: 1), privacy: .public) ms")
                #if DEBUG
                self?.runDemo()
                #endif
            }
        }

        #if DEBUG
        /// Screenshots only (#80): the caret in the first open to-do without a
        /// task, and with -SchemaDemoTaskMenu its right-click menu.
        private func runDemo() {
            if DemoData.isEnabled, DemoData.typesMention {
                runMentionDemo()
                return
            }
            guard DemoData.isEnabled, DemoData.showsMakeTask || DemoData.opensTaskMenu || DemoData.opensLinkedTaskMenu else { return }
            let script = """
            setTimeout(() => {
              const li = [...document.querySelectorAll('ul[data-type="taskList"] > li')]
                .find((el) => el.querySelector(linked ? ':scope > div > .schema-task-link' : ':scope > div > .schema-make-task'))
              if (!li) return
              const p = li.querySelector('p')
              const range = document.createRange(); range.selectNodeContents(p); range.collapse(false)
              const sel = getSelection(); sel.removeAllRanges(); sel.addRange(range)
              document.querySelector('.ProseMirror').focus()
              if (menu) {
                const r = p.getBoundingClientRect()
                p.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true, clientX: r.left + 120, clientY: r.top + 12 }))
              }
            }, 300)
            """
            webView?.window?.makeFirstResponder(webView)
            webView?.callAsyncJavaScript(script, arguments: ["menu": DemoData.opensTaskMenu || DemoData.opensLinkedTaskMenu, "linked": DemoData.opensLinkedTaskMenu], in: nil, in: .page)
        }

        /// Types "Talk it through in @Ideas, then @tod", choosing Ideas from
        /// the menu and leaving it open for "tod".
        private func runMentionDemo() {
            let script = """
            const wait = (ms) => new Promise((r) => setTimeout(r, ms))
            const dom = document.querySelector('.ProseMirror')
            await wait(400)
            window.schemaEditor.focus('end')
            await wait(150)
            const type = async (text) => { for (const ch of text) { document.execCommand('insertText', false, ch); await wait(15) } }
            const key = (k) => dom.dispatchEvent(new KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true }))
            await type(' Talk it through in @ide')
            await wait(150)
            key('Enter')
            await type('on @tom')
            await wait(150)
            key('Enter')
            await type('at @tod')
            """
            webView?.window?.makeFirstResponder(webView)
            webView?.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page)
        }
        #endif

        func update(from view: TipTapEditorView) {
            bridge.onChange = view.onChange
            bridge.onMakeTask = view.onMakeTask
            bridge.onOpenTask = view.onOpenTask
            bridge.onMoveTask = view.onMoveTask
            bridge.onOpenMention = view.onOpenMention
            bridge.onSubmit = view.onSubmit
            bridge.setMode(view.mode)
            bridge.onChangeDefaultPage = view.onChangeDefaultPage
            onEscape = view.onEscape
            bridge.show(view.documentJSON, key: view.documentKey)
            bridge.setTaskContext(view.taskContextJSON ?? EditorTaskContext().json)
            bridge.setMentionContext(view.mentionContextJSON ?? EditorMentionContext().json)
            bridge.focus(view.focusRequest)
        }

        func run(_ script: String, arguments: [String: Any]) {
            if script.contains(".focus(") { webView?.window?.makeFirstResponder(webView) }
            webView?.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            bridge.receive(body)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            TipTapEditorView.log.error("Editor failed to load: \(error.localizedDescription, privacy: .public)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            TipTapEditorView.log.error("Editor failed to load: \(error.localizedDescription, privacy: .public)")
        }

        /// Links in the page never navigate the editor away.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            action.navigationType == .other ? .allow : .cancel
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            TipTapEditorView.log.error("Editor web process ended; reloading")
            bridge.pageDidReset()
            webView.reload()
        }
    }

    /// WKUserContentController keeps its handlers strongly; this breaks the cycle.
    private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: (any WKScriptMessageHandler)?
        init(_ target: any WKScriptMessageHandler) { self.target = target }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(controller, didReceive: message)
        }
    }
}

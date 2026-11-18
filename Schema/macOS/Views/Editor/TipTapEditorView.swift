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
            bridge.onLoaded = { TipTapEditorView.log.info("Editor showed a document in \($0, format: .fixed(precision: 1), privacy: .public) ms") }
        }

        func update(from view: TipTapEditorView) {
            bridge.onChange = view.onChange
            onEscape = view.onEscape
            bridge.show(view.documentJSON, key: view.documentKey)
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

//
//  QuickNoteController.swift
//  Schema
//
//  Quick note (#41): ⌃⌥N anywhere on the Mac opens a small floating panel.
//  Return saves the note to the chosen scratchpad, ⌘Return saves it as a
//  task, Esc or a click elsewhere closes it. The panel doesn't bring
//  Schema's window forward, so you stay in the app you were using.
//

import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI

@MainActor
final class QuickNoteController {
    static let shared = QuickNoteController()

    private var container: ModelContainer?
    private var hotKey: GlobalHotKey?
    private var panel: QuickNotePanel?
    private let model = QuickNoteModel()

    /// Call once the store is open.
    func start(container: ModelContainer) {
        self.container = container
        #if DEBUG
        if DemoData.isEnabled, DemoData.opensQuickNote {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.show()
                self?.model.setNote(TipTapDocument.json(TipTapDocument.document(from: [
                    TipTapDocument.Line(kind: .text, text: "Friday weekly review as a page template: wins, misses, next week’s top three"),
                ])))
            }
        }
        #endif
        guard hotKey == nil else { return }
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if panel?.isVisible == true { close() } else { show() }
    }

    func show() {
        guard let container else { return }
        let context = container.mainContext
        let lists = (try? context.fetch(FetchDescriptor<SchemaList>(sortBy: [SortDescriptor(\.order)]))) ?? []
        model.scratchpads = lists.filter(\.isScratchpad)
        model.targetID = QuickNoteStore.targetPage(in: lists, preferredID: SchemaPreferences.quickNotePageID)?.id
        model.mentionContextJSON = Self.mentionContext(lists: lists, context: context).json
        // A fresh note, with its own undo history.
        model.documentKey = UUID().uuidString
        model.setNote(PageDocument.emptyJSON)
        model.focusRequest = EditorFocusRequest(position: .end)

        let panel = self.panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// Pages and open tasks the note can @ mention (#81).
    private static func mentionContext(lists: [SchemaList], context: ModelContext) -> EditorMentionContext {
        let open = (try? context.fetch(FetchDescriptor<SchemaTask>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []
        var mentions = EditorMentionContext()
        mentions.pages = lists.filter { !$0.isEverythingList }.map {
            .init(id: $0.id.uuidString, title: $0.title, kind: $0.pageKind.rawValue)
        }
        mentions.tasks = open.map { .init(id: $0.id.uuidString, title: $0.title, page: $0.list?.title ?? "") }
        return mentions
    }

    private func save(asTask: Bool, json: String? = nil) {
        if let json { model.setNote(json) }
        guard let container, !model.isEmpty else { return }
        let context = container.mainContext
        let lists = (try? context.fetch(FetchDescriptor<SchemaList>())) ?? []
        if asTask {
            let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
            QuickNoteStore.saveTask(model.text, lists: lists, allTasks: tasks, defaultPageID: SchemaPreferences.defaultWritableListID, context: context)
        } else {
            QuickNoteStore.saveNote(documentJSON: model.documentJSON, lists: lists, preferredPageID: model.targetID, context: context)
        }
        close()
    }

    private func makePanel() -> QuickNotePanel {
        let panel = QuickNotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.onResignKey = { [weak self] in self?.close() }
        let view = QuickNoteView(
            model: model,
            onSave: { [weak self] asTask, json in self?.save(asTask: asTask, json: json) },
            onClose: { [weak self] in self?.close() }
        )
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        return panel
    }

    /// Centred on the screen with the mouse, about a fifth of the way down.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - frame.height * 0.2 - size.height)
        panel.setFrameOrigin(origin)
    }
}

/// A borderless panel that can still take the keyboard.
final class QuickNotePanel: NSPanel {
    var onResignKey: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

@MainActor
@Observable
final class QuickNoteModel {
    /// The note as TipTap JSON text (#82), and as plain text for Save as task.
    private(set) var documentJSON = PageDocument.emptyJSON
    private(set) var text = ""
    var documentKey = UUID().uuidString
    var mentionContextJSON = EditorMentionContext().json
    var scratchpads: [SchemaList] = []
    var targetID: UUID?
    var focusRequest: EditorFocusRequest?

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func setNote(_ json: String) {
        documentJSON = json
        text = PageDocument.summary(of: json).text
    }

    var targetTitle: String {
        scratchpads.first { $0.id == targetID }?.title ?? QuickNoteStore.defaultPageTitle
    }
}

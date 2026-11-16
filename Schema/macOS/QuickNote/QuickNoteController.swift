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
                self?.model.text = "Friday weekly review as a page template: wins, misses, next week’s top three"
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
        model.text = ""
        model.focusToken = BlockFocusRequest(blockID: QuickNoteModel.fieldID, caret: .end)

        let panel = self.panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func save(asTask: Bool) {
        guard let container else { return }
        let context = container.mainContext
        let lists = (try? context.fetch(FetchDescriptor<SchemaList>())) ?? []
        if asTask {
            let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>())) ?? []
            QuickNoteStore.saveTask(model.text, lists: lists, allTasks: tasks, defaultPageID: SchemaPreferences.defaultWritableListID, context: context)
        } else {
            QuickNoteStore.saveNote(model.text, lists: lists, preferredPageID: model.targetID, context: context)
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
            onSave: { [weak self] asTask in self?.save(asTask: asTask) },
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
    static let fieldID = UUID()
    var text = ""
    var scratchpads: [SchemaList] = []
    var targetID: UUID?
    var focusToken: BlockFocusRequest?

    var targetTitle: String {
        scratchpads.first { $0.id == targetID }?.title ?? QuickNoteStore.defaultPageTitle
    }
}

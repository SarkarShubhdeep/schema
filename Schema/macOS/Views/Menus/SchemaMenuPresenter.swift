//
//  SchemaMenuPresenter.swift
//  Schema
//
//  Shows a Schema menu (#83) in a small floating panel, like a macOS menu:
//  it never takes the window's focus (the editor keeps its caret, Quick note
//  stays open), keys go to the open menu until it closes, and a click
//  anywhere else closes it. Submenus open beside their row.
//

import AppKit
import SwiftUI

@MainActor
final class SchemaMenuPresenter {
    static let shared = SchemaMenuPresenter()

    /// The open menus, root first, then any submenus.
    private var levels: [Level] = []
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []

    var isOpen: Bool { !levels.isEmpty }

    private final class Level {
        let model: SchemaMenuModel
        let panel: SchemaMenuPanel
        init(model: SchemaMenuModel, panel: SchemaMenuPanel) {
            self.model = model
            self.panel = panel
        }
    }

    /// Opens `items` below `anchor` (a screen rect), or above it when there
    /// is no room below. `minWidth` lines a dropdown up with its button; a
    /// small icon button (⋯) gets its menu lined up with its right edge.
    func show(_ items: [SchemaMenuItem], below anchor: NSRect, minWidth: CGFloat = 0, label: String) {
        close()
        let alignsRight = minWidth == 0 && anchor.width < 44
        open(items, label: label, minWidth: minWidth) { size, screen in
            var origin = NSPoint(x: alignsRight ? anchor.maxX - size.width : anchor.minX, y: anchor.minY - 4 - size.height)
            if origin.y < screen.minY + 8 { origin.y = anchor.maxY + 4 }
            return origin
        }
    }

    /// Opens `items` with its top-left corner at `point` (a screen point), for right-click menus.
    func show(_ items: [SchemaMenuItem], at point: NSPoint, label: String) {
        close()
        open(items, label: label, minWidth: 0) { size, screen in
            var origin = NSPoint(x: point.x, y: point.y - size.height)
            if origin.y < screen.minY + 8 { origin.y = point.y }
            return origin
        }
    }

    func close() {
        guard !levels.isEmpty else { return }
        for level in levels { level.panel.orderOut(nil) }
        levels.removeAll()
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    // MARK: Panels

    private func open(_ items: [SchemaMenuItem], label: String, minWidth: CGFloat, place: (CGSize, NSRect) -> NSPoint) {
        let depth = levels.count
        let model = SchemaMenuModel(items: items, label: label)
        model.onChoose = { [weak self] index in self?.choose(index, depth: depth) }
        model.onHover = { [weak self] index in self?.hover(index, depth: depth) }
        let panel = SchemaMenuPanel(model: model, minWidth: minWidth)
        let size = panel.frame.size
        let screen = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin = place(size, screen)
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
        origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        levels.append(Level(model: model, panel: panel))
        if depth == 0 { startWatching() }
        NSAccessibility.post(element: panel, notification: .created)
    }

    private func openSubmenu(at index: Int, depth: Int, selectFirst: Bool) {
        guard levels.indices.contains(depth), let items = levels[depth].model.items[index].submenu else { return }
        closeLevels(after: depth)
        let parent = levels[depth]
        guard let row = parent.model.rowFrames[index] else { return }
        // Beside its row: the row's frame is in the panel's flipped content coordinates.
        let panelFrame = parent.panel.frame
        let rowTop = panelFrame.maxY - row.minY
        open(items, label: parent.model.items[index].title, minWidth: 0) { size, screen in
            var origin = NSPoint(x: panelFrame.maxX + 2, y: rowTop + 6 - size.height)
            if origin.x + size.width > screen.maxX - 8 { origin.x = panelFrame.minX - 2 - size.width }
            return origin
        }
        if selectFirst { levels.last?.model.navigator.moveDown() ; levels.last?.model.byKeyboard = true }
    }

    private func closeLevels(after depth: Int) {
        while levels.count > depth + 1 {
            levels.removeLast().panel.orderOut(nil)
        }
    }

    // MARK: Choosing

    private func choose(_ index: Int, depth: Int) {
        guard levels.indices.contains(depth) else { return }
        let item = levels[depth].model.items[index]
        guard item.isChoosable else { return }
        switch item.kind {
        case .submenu:
            openSubmenu(at: index, depth: depth, selectFirst: true)
        case .action(let run):
            close()
            // After the menu is gone, so a sheet or rename it starts takes focus cleanly.
            DispatchQueue.main.async { run() }
        case .header, .divider:
            break
        }
    }

    private func hover(_ index: Int?, depth: Int) {
        guard levels.indices.contains(depth) else { return }
        let model = levels[depth].model
        model.byKeyboard = false
        guard let index else { return }
        model.navigator.selected = model.items[index].isChoosable ? index : nil
        if model.items[index].submenu != nil, model.items[index].isChoosable {
            if levels.count <= depth + 1 || levels[depth + 1].model.label != model.items[index].title {
                openSubmenu(at: index, depth: depth, selectFirst: false)
            }
        } else {
            closeLevels(after: depth)
        }
    }

    // MARK: Keys and clicks

    private func startWatching() {
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isOpen else { return event }
            return self.handleKey(event) ? nil : event
        } as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, self.isOpen else { return event }
            if let depth = self.levels.firstIndex(where: { $0.panel === event.window }) {
                // Choose here and keep the click from the rest of the app,
                // so a popover the menu came from doesn't take it as a click outside.
                if event.type == .leftMouseDown, let index = self.row(at: event.locationInWindow, depth: depth) {
                    self.choose(index, depth: depth)
                }
                return nil
            }
            self.close()
            // A click elsewhere only closes the menu, as in macOS.
            return nil
        } as Any)
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] note in
            // The window the menu belongs to went away (closed, or another app).
            MainActor.assumeIsolated {
                guard let self, let window = note.object as? NSWindow, !(window is SchemaMenuPanel) else { return }
                if NSApp.keyWindow == nil { self.close() }
            }
        })
    }

    /// The choosable row under a point in a menu panel's window coordinates.
    private func row(at point: NSPoint, depth: Int) -> Int? {
        let level = levels[depth]
        let flipped = CGPoint(x: point.x, y: level.panel.frame.height - point.y)
        return level.model.rowFrames.first { $0.value.contains(flipped) && level.model.items[$0.key].isChoosable }?.key
    }

    /// Returns true when the menu used the key.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let depth = levels.indices.last else { return false }
        let model = levels[depth].model
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        switch Int(event.keyCode) {
        case 125: // ↓
            model.byKeyboard = true
            model.navigator.moveDown()
        case 126: // ↑
            model.byKeyboard = true
            model.navigator.moveUp()
        case 36, 76, 49: // Return, Enter, Space
            if let selected = model.navigator.selected { choose(selected, depth: depth) }
        case 124: // →
            if let selected = model.navigator.selected, model.items[selected].submenu != nil {
                openSubmenu(at: selected, depth: depth, selectFirst: true)
            }
        case 123: // ←
            if depth > 0 { closeLevels(after: depth - 1) }
        case 53: // Esc
            if depth > 0 { closeLevels(after: depth - 1) } else { close() }
        case 48: // Tab
            model.byKeyboard = true
            if event.modifierFlags.contains(.shift) { model.navigator.moveUp() } else { model.navigator.moveDown() }
        default:
            guard modifiers.isEmpty, let text = event.charactersIgnoringModifiers, !text.isEmpty,
                  text.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == " " }) else {
                // ⌘ shortcuts close the menu and go through, as in macOS.
                if !modifiers.isEmpty { close(); return false }
                return true
            }
            model.byKeyboard = true
            model.navigator.type(text)
        }
        return true
    }
}

#if DEBUG
extension SchemaMenuPresenter {
    /// Posts a real right click into the main window, as a person would.
    static func rightClickForDemo(atFraction spot: CGPoint) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.width >= 1000 }) else { return }
        let size = window.contentView?.bounds.size ?? window.frame.size
        let point = NSPoint(x: size.width * spot.x, y: size.height * (1 - spot.y))
        for type in [NSEvent.EventType.rightMouseDown, .rightMouseUp] {
            if let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ) {
                NSApp.postEvent(event, atStart: false)
            }
        }
    }

    /// Screenshots and checks only: press -SchemaDemoMenuKeys, then click
    /// row -SchemaDemoMenuClick of the deepest menu with a real mouse event.
    func runDemo() async {
        let codes: [String: UInt16] = ["down": 125, "up": 126, "right": 124, "left": 123, "return": 36, "esc": 53]
        for key in DemoData.menuKeys {
            try? await Task.sleep(for: .milliseconds(250))
            guard let code = codes[key], let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code
            ) else { continue }
            _ = handleKey(event)
        }
        guard let row = DemoData.menuClick, let level = levels.last, let frame = level.model.rowFrames[row] else { return }
        try? await Task.sleep(for: .milliseconds(400))
        let panel = level.panel
        let point = NSPoint(x: frame.midX, y: panel.frame.height - frame.midY)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ) {
                NSApp.postEvent(event, atStart: false)
            }
        }
    }
}
#endif

/// One open menu: its items and where the keyboard or pointer is.
@MainActor
@Observable
final class SchemaMenuModel {
    let items: [SchemaMenuItem]
    let label: String
    var navigator: SchemaMenuNavigator
    /// The selection moved by keyboard: show the focus ring, as macOS does for keyboard focus.
    var byKeyboard = false
    /// Row frames in the panel's content, for placing submenus.
    @ObservationIgnored var rowFrames: [Int: CGRect] = [:]
    @ObservationIgnored var onChoose: (Int) -> Void = { _ in }
    @ObservationIgnored var onHover: (Int?) -> Void = { _ in }

    init(items: [SchemaMenuItem], label: String) {
        self.items = items
        self.label = label
        navigator = SchemaMenuNavigator(items: items)
    }
}

/// A borderless panel that floats above every window, Quick note included,
/// and never becomes key.
final class SchemaMenuPanel: NSPanel {
    init(model: SchemaMenuModel, minWidth: CGFloat) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        // The window's own shadow follows the rounded panel, like a macOS menu.
        hasShadow = true
        hidesOnDeactivate = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let host = NSHostingView(rootView: SchemaMenuView(model: model, minWidth: minWidth))
        contentView = host
        setContentSize(host.fittingSize)
        invalidateShadow()
        setAccessibilityRole(.menu)
        setAccessibilityLabel(model.label)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

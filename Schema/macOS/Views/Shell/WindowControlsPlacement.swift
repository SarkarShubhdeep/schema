//
//  WindowControlsPlacement.swift
//  Schema
//
//  Moves the window's own close, minimise and zoom buttons into the
//  sidebar's header row (#116), so they sit inside the sidebar island, or
//  inside the pill when it's collapsed. They stay the real buttons, so
//  hover, Option-click and the zoom menu all work.
//
//  AppKit lays them out again on resize, on going full screen and back,
//  and when the window becomes key, so the offset is applied again then.
//  In full screen they're left where macOS puts them.
//

import AppKit
import SwiftUI

struct WindowControlsPlacement: NSViewRepresentable {
    func makeNSView(context: Context) -> PlacementView {
        PlacementView()
    }

    func updateNSView(_ nsView: PlacementView, context: Context) {
        nsView.place()
    }

    final class PlacementView: NSView {
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didChangeScreenNotification,
            ]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.place() }
                }
            }
            place()
        }

        override func layout() {
            super.layout()
            place()
        }

        func place() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let titlebar = close.superview,
                  let container = titlebar.superview else { return }
            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            let size = close.frame.size
            // Room for the buttons with their usual spacing, and no more,
            // so the strip doesn't swallow clicks meant for the page.
            let spacing: CGFloat = 20
            let stripHeight = size.height + 8
            let stripWidth = ShellMetrics.windowControlsLeading + spacing * 2 + size.width + 8
            let frame = NSRect(
                x: 0,
                y: window.frame.height - ShellMetrics.windowControlsCenterY - stripHeight / 2,
                width: stripWidth,
                height: stripHeight
            )
            if container.frame != frame { container.frame = frame }
            if titlebar.frame != container.bounds { titlebar.frame = container.bounds }
            for (index, type) in buttons.enumerated() {
                guard let button = window.standardWindowButton(type) else { continue }
                let origin = NSPoint(
                    x: ShellMetrics.windowControlsLeading + CGFloat(index) * spacing,
                    y: (stripHeight - size.height) / 2
                )
                if button.frame.origin != origin { button.setFrameOrigin(origin) }
            }
        }
    }
}

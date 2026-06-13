//
//  ClickOutsideDismiss.swift
//  Schema
//

import AppKit
import SwiftUI

struct ClickOutsideDismiss: ViewModifier {
    let isActive: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.background(
            ClickOutsideMonitorRepresentable(isActive: isActive, onDismiss: onDismiss)
                .frame(width: 0, height: 0)
        )
    }
}

private struct ClickOutsideMonitorRepresentable: NSViewRepresentable {
    let isActive: Bool
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDismiss = onDismiss
        context.coordinator.setActive(isActive)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.setActive(false)
    }

    final class Coordinator {
        var onDismiss: () -> Void
        private weak var hostView: NSView?
        private var monitor: Any?
        private var isActive = false

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func attach(to view: NSView) {
            hostView = view
        }

        func setActive(_ active: Bool) {
            guard active != isActive else { return }
            isActive = active

            if active {
                installMonitor()
            } else {
                removeMonitor()
            }
        }

        private func installMonitor() {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, self.isActive else { return event }
                guard self.shouldDismiss(for: event) else { return event }
                DispatchQueue.main.async {
                    self.onDismiss()
                }
                return event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func shouldDismiss(for event: NSEvent) -> Bool {
            guard let window = event.window,
                  let contentView = window.contentView else {
                return false
            }

            let locationInContent = contentView.convert(event.locationInWindow, from: nil)
            guard let hitView = contentView.hitTest(locationInContent) else {
                return true
            }

            return !containsTextInput(hitView)
        }

        private func containsTextInput(_ view: NSView) -> Bool {
            var current: NSView? = view
            while let node = current {
                if node is NSTextField || node is NSTextView || node is NSSearchField {
                    return true
                }
                if node.className.contains("TextField") || node.className.contains("TextEditor") {
                    return true
                }
                current = node.superview
            }
            return false
        }

        deinit {
            removeMonitor()
        }
    }
}

extension View {
    func clickOutsideDismiss(isActive: Bool, onDismiss: @escaping () -> Void) -> some View {
        modifier(ClickOutsideDismiss(isActive: isActive, onDismiss: onDismiss))
    }
}

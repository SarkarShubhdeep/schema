//
//  SchemaMenuTriggers.swift
//  Schema
//
//  Opening Schema menus (#83): SchemaMenuButton for dropdowns and ⋯ menus,
//  and .schemaContextMenu for right-click (and Control-click) menus. Both
//  stand in for SwiftUI's Menu and .contextMenu, which only draw macOS menus.
//

import AppKit
import SwiftUI

/// A button that opens a Schema menu below itself.
struct SchemaMenuButton<Label: View>: View {
    let accessibilityLabel: String
    /// Line the menu up with the button's width (pickers); ⋯ menus leave it off.
    var matchesWidth = false
    let items: () -> [SchemaMenuItem]
    @ViewBuilder let label: () -> Label

    @State private var anchor = ScreenAnchor()

    init(
        _ accessibilityLabel: String,
        matchesWidth: Bool = false,
        @SchemaMenuBuilder items: @escaping () -> [SchemaMenuItem],
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.matchesWidth = matchesWidth
        self.items = items
        self.label = label
    }

    var body: some View {
        Button(action: open) { label() }
            .buttonStyle(.plain)
            .background(ScreenAnchorReader(anchor: anchor))
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens a menu")
            #if DEBUG
            .task {
                guard DemoData.isEnabled, DemoData.opensMenu == accessibilityLabel else { return }
                try? await Task.sleep(for: .milliseconds(1500))
                open()
                await SchemaMenuPresenter.shared.runDemo()
            }
            #endif
    }

    private func open() {
        let rect = anchor.screenRect ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        SchemaMenuPresenter.shared.show(items(), below: rect, minWidth: matchesWidth ? rect.width : 0, label: accessibilityLabel)
    }
}

/// A dropdown for choosing one value (Settings, forms): the choice and a
/// chevron in a pill, and a menu with a check on the current value.
struct SchemaMenuPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    var body: some View {
        let current = options.first { $0.value == selection }?.label ?? "None"
        SchemaMenuButton(title, matchesWidth: true) {
            options.map { option in
                SchemaMenuItem.action(option.label, isChecked: option.value == selection) { selection = option.value }
            }
        } label: {
            HStack(spacing: 6) {
                Text(current).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.satoshi(13, weight: .medium, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.ink)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(SchemaTheme.surfaceHover))
            .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .accessibilityValue(current)
    }
}

extension View {
    /// A Schema menu on right-click or Control-click, and as the
    /// VoiceOver "Show menu" action.
    func schemaContextMenu(_ label: String = "Options", @SchemaMenuBuilder _ items: @escaping () -> [SchemaMenuItem]) -> some View {
        modifier(SchemaContextMenuModifier(label: label, items: items))
    }
}

private struct SchemaContextMenuModifier: ViewModifier {
    let label: String
    let items: () -> [SchemaMenuItem]
    @State private var anchor = ScreenAnchor()

    func body(content: Content) -> some View {
        content
            .overlay(RightClickCatcher { point in
                SchemaMenuPresenter.shared.show(items(), at: point, label: label)
            })
            .background(ScreenAnchorReader(anchor: anchor))
            .accessibilityAction(named: "Show menu") {
                let rect = anchor.screenRect ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
                SchemaMenuPresenter.shared.show(items(), at: NSPoint(x: rect.minX + 12, y: rect.minY), label: label)
            }
    }
}

// MARK: AppKit helpers

/// Where a view is on screen, kept by reference so reading it never redraws.
final class ScreenAnchor {
    weak var view: NSView?

    var screenRect: NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

private struct ScreenAnchorReader: NSViewRepresentable {
    let anchor: ScreenAnchor

    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}

private final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Takes right clicks and Control-clicks only; every other click goes to
/// the views underneath.
private struct RightClickCatcher: NSViewRepresentable {
    let onMenu: (NSPoint) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onMenu = onMenu
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onMenu = onMenu
    }

    final class CatcherView: NSView {
        var onMenu: (NSPoint) -> Void = { _ in }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            let isMenuClick = event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            return isMenuClick ? super.hitTest(point) : nil
        }

        override func rightMouseDown(with event: NSEvent) {
            onMenu(screenPoint(of: event))
        }

        override func mouseDown(with event: NSEvent) {
            onMenu(screenPoint(of: event))
        }

        /// Where the click happened, on screen.
        private func screenPoint(of event: NSEvent) -> NSPoint {
            event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        }

        override func menu(for event: NSEvent) -> NSMenu? { nil }
    }
}

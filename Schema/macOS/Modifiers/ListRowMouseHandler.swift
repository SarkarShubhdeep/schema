//
//  ListRowMouseHandler.swift
//  Schema
//

import AppKit
import SwiftUI

/// Forwards mouse events to the underlying `List` row so `onMove` reordering keeps working
/// alongside single- and double-click actions.
final class ListRowMouseHandlerView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        didDrag = false

        if event.clickCount == 2 {
            onDoubleClick?()
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag, event.clickCount == 1 {
            onSingleClick?()
        }

        super.mouseUp(with: event)
    }
}

struct ListRowMouseHandler: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ListRowMouseHandlerView {
        let view = ListRowMouseHandlerView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: ListRowMouseHandlerView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

extension View {
    func listRowClickHandling(
        onSingleClick: @escaping () -> Void,
        onDoubleClick: @escaping () -> Void
    ) -> some View {
        self
            // Background handler: sits behind interactive controls so checkbox/reminder
            // buttons receive their own clicks. The SwiftUI hosting layer absorbs events
            // over the content, so this NSView only reliably sees events on inert areas
            // and drag operations (needed for onMove reordering).
            .background {
                ListRowMouseHandler(
                    onSingleClick: onSingleClick,
                    onDoubleClick: onDoubleClick
                )
            }
            // SwiftUI-level double-tap: catches double-clicks on the content area that
            // the background NSView never receives. simultaneousGesture lets the Button
            // still handle its own single-tap on the checkbox.
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { onDoubleClick() }
            )
    }
}

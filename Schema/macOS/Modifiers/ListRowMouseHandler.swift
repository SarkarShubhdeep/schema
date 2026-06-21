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
        // Sits behind the row so interactive controls (checkbox, reminder button)
        // receive their own clicks; inert areas fall through to this handler.
        background {
            ListRowMouseHandler(
                onSingleClick: onSingleClick,
                onDoubleClick: onDoubleClick
            )
        }
    }
}

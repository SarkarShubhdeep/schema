//
//  ThemedScrollBars.swift
//  Schema
//
//  Never the system scroll bars (#121). Every scroll view gets a thin,
//  rounded thumb in ink at 16% with no track. It uses AppKit's overlay
//  scroller, so it appears while scrolling or when the pointer nears the
//  edge, and fades out on its own.
//

import AppKit
import SwiftUI

extension View {
    /// Put inside a ScrollView's content: swaps that scroll view's scroll
    /// bars for themed ones.
    func themedScrollBars() -> some View {
        background(ThemedScrollBarsInstaller())
    }
}

private struct ThemedScrollBarsInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> InstallerView { InstallerView() }
    func updateNSView(_ nsView: InstallerView, context: Context) { nsView.install() }
}

private final class InstallerView: NSView {
    private var styleObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        install()
        guard styleObserver == nil, window != nil else { return }
        // "Always show scroll bars" in System Settings resets the style.
        styleObserver = NotificationCenter.default.addObserver(
            forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.install() }
        }
    }

    deinit {
        if let styleObserver { NotificationCenter.default.removeObserver(styleObserver) }
    }

    func install() {
        guard let scrollView = enclosingScrollView else { return }
        scrollView.scrollerStyle = .overlay
        #if DEBUG
        // Screenshots: always show them (legacy style never hides).
        if DemoData.isEnabled, DemoData.showsScrollBars { scrollView.scrollerStyle = .legacy }
        #endif
        scrollView.autohidesScrollers = true
        if !(scrollView.verticalScroller is ThemedScroller) {
            scrollView.verticalScroller = ThemedScroller()
        }
        if scrollView.hasHorizontalScroller, !(scrollView.horizontalScroller is ThemedScroller) {
            scrollView.horizontalScroller = ThemedScroller()
        }
        scrollView.scrollerKnobStyle = .default
    }
}

/// A scroller with no track and a 4pt capsule thumb in the theme's ink.
final class ThemedScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        10
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // No track.
    }

    override func drawKnob() {
        let knob = rect(for: .knob)
        guard !knob.isEmpty else { return }
        let isVertical = bounds.height >= bounds.width
        let thickness: CGFloat = 4
        let inset: CGFloat = 2
        let shape = isVertical
            ? NSRect(x: knob.maxX - thickness - inset, y: knob.minY + inset, width: thickness, height: knob.height - inset * 2)
            : NSRect(x: knob.minX + inset, y: knob.maxY - thickness - inset, width: knob.width - inset * 2, height: thickness)
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let ink = isDark ? NSColor(srgbRed: 0.949, green: 0.949, blue: 0.937, alpha: 1)
                         : NSColor(srgbRed: 0.082, green: 0.082, blue: 0.082, alpha: 1)
        ink.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: shape, xRadius: thickness / 2, yRadius: thickness / 2).fill()
    }
}

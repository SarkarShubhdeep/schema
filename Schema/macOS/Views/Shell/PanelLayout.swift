//
//  PanelLayout.swift
//  Schema
//
//  Side panel behaviour: manual toggles (⌘⌥← / ⌘⌥→) and auto-collapse by
//  window width. At 1200pt and wider both panels are open, from 960 to 1199
//  the details panel collapses, and under 960 both collapse. A manual choice
//  holds until the window crosses a breakpoint.
//

import AppKit
import SwiftUI

enum WindowWidthTier: Equatable {
    case narrow
    case medium
    case wide

    static let mediumMinWidth: CGFloat = 960
    static let wideMinWidth: CGFloat = 1200

    init(width: CGFloat) {
        if width >= Self.wideMinWidth {
            self = .wide
        } else if width >= Self.mediumMinWidth {
            self = .medium
        } else {
            self = .narrow
        }
    }

    var showsSidebar: Bool { self != .narrow }
    var showsDetailsPanel: Bool { self == .wide }
}

extension WorkspaceState {
    func toggleSidebar() {
        withPanelAnimation {
            isSidebarCollapsed.toggle()
            if !isSidebarCollapsed, !fits(sidebarCollapsed: false, detailsCollapsed: isDetailsPanelCollapsed) {
                isDetailsPanelCollapsed = true
            }
        }
    }

    func toggleDetailsPanel() {
        withPanelAnimation {
            isDetailsPanelCollapsed.toggle()
            if !isDetailsPanelCollapsed, !fits(sidebarCollapsed: isSidebarCollapsed, detailsCollapsed: false) {
                isSidebarCollapsed = true
            }
        }
    }

    /// Called whenever the window width changes.
    func windowWidthChanged(to width: CGFloat) {
        let tier = WindowWidthTier(width: width)
        let previousTier = windowWidthTier
        windowWidth = width
        windowWidthTier = tier

        if previousTier == nil {
            // First layout: keep the saved state, but collapse whatever doesn't fit.
            if !tier.showsSidebar { isSidebarCollapsed = true }
            if !tier.showsDetailsPanel { isDetailsPanelCollapsed = true }
            return
        }
        guard tier != previousTier else { return }

        withPanelAnimation {
            isSidebarCollapsed = !tier.showsSidebar
            isDetailsPanelCollapsed = !tier.showsDetailsPanel
        }
    }

    private func fits(sidebarCollapsed: Bool, detailsCollapsed: Bool) -> Bool {
        guard let windowWidth else { return true }
        let needed = (sidebarCollapsed ? ShellMetrics.floatingBarContentInset : ShellMetrics.sidebarWidth)
            + ShellMetrics.mainMinWidth
            + (detailsCollapsed ? ShellMetrics.detailsRailWidth : ShellMetrics.detailsWidth)
        return needed <= windowWidth
    }

    private func withPanelAnimation(_ changes: () -> Void) {
        withAnimation(SchemaMotion.smooth, changes)
    }
}

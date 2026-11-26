//
//  ShellMetrics.swift
//  Schema
//
//  The window's grid (#116): floating islands 16pt from the window edges
//  and 16pt apart, each with a 16pt corner and 8pt padding; what's inside
//  has 8pt corners, 8pt gaps and 44pt controls.
//

import CoreGraphics

enum ShellMetrics {
    /// Space between the window edge and an island, and between islands.
    static let margin: CGFloat = 16
    static let islandPadding: CGFloat = 8
    static let islandRadius: CGFloat = 16
    /// Corners of rows and blocks inside an island: the island's corner less its padding.
    static let innerRadius: CGFloat = 8
    static let innerGap: CGFloat = 8
    /// Buttons in an island's header and footer.
    static let control: CGFloat = 44
    /// The header islands: one row of controls and the padding around it.
    static let headerHeight: CGFloat = control + islandPadding * 2

    static let sidebarWidth: CGFloat = 283
    static let detailsWidth: CGFloat = 283
    /// Collapsed, the sidebar is a pill with the window controls and the
    /// expand button; the details panel is its expand button alone.
    static let collapsedSidebarWidth: CGFloat = 150
    static let collapsedDetailsWidth: CGFloat = headerHeight

    /// Every page's content is capped at this width and centred.
    static let contentWidth: CGFloat = 600
    static let mainMinWidth: CGFloat = 420
    /// Narrowest window: both panels collapsed.
    static let minimumWindowWidth: CGFloat = margin + mainMinWidth + margin

    /// Where the window controls sit (#116): inside the sidebar's header row,
    /// 12pt into it, centred on the row.
    static let windowControlsLeading: CGFloat = margin + islandPadding + 12
    static let windowControlsCenterY: CGFloat = margin + headerHeight / 2

    /// Width a side takes from the main column, island and gap.
    static func leadingWidth(sidebarCollapsed: Bool) -> CGFloat {
        sidebarCollapsed ? 0 : sidebarWidth + margin
    }

    static func trailingWidth(detailsCollapsed: Bool) -> CGFloat {
        detailsCollapsed ? 0 : detailsWidth + margin
    }
}

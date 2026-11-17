//
//  ShellMetrics.swift
//  Schema
//
//  Column widths from the dashboard design.
//

import CoreGraphics

enum ShellMetrics {
    static let sidebarWidth: CGFloat = 240
    /// Collapsed, the sidebar is a floating bar over the main column (#43):
    /// 48pt wide, 12pt from the window edge. The main column's content moves
    /// right by this much so the bar never covers it.
    static let floatingBarWidth: CGFloat = 48
    static let floatingBarEdgeInset: CGFloat = 12
    static let floatingBarContentInset: CGFloat = floatingBarEdgeInset + floatingBarWidth
    static let detailsWidth: CGFloat = 300
    static let detailsRailWidth: CGFloat = 52
    static let mainMinWidth: CGFloat = 420
    /// Narrowest window: the sidebar floating and the details panel a rail.
    static let minimumWindowWidth: CGFloat = floatingBarContentInset + mainMinWidth + detailsRailWidth
    /// Height of the hidden title bar strip that holds the window controls.
    static let titleBarHeight: CGFloat = 28
    /// Vertical centre of the window controls, measured from the window top.
    static let windowControlsCenterY: CGFloat = 16
}

//
//  ShellMetrics.swift
//  Schema
//
//  Column widths from the dashboard design.
//

import CoreGraphics

enum ShellMetrics {
    static let sidebarWidth: CGFloat = 240
    static let sidebarRailWidth: CGFloat = 72
    static let detailsWidth: CGFloat = 300
    static let detailsRailWidth: CGFloat = 52
    static let mainMinWidth: CGFloat = 420
    /// Narrowest window: both panels collapsed to rails. Auto-collapse by width arrives in #11.
    static let minimumWindowWidth: CGFloat = sidebarRailWidth + mainMinWidth + detailsRailWidth
    /// Vertical centre of the window controls, measured from the window top.
    static let windowControlsCenterY: CGFloat = 16
}

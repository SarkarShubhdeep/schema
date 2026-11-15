//
//  SchemaTheme.swift
//  Schema
//
//  Color tokens from the Schema design system
//  (https://claude.ai/artifact/5fDFJNPDcbr1nWJwyGSG9L): neutral greys and a
//  single yellow accent, each with a light and a dark value.
//

import AppKit
import SwiftUI

enum SchemaTheme {
    // MARK: Grounds, back to front

    /// Sidebar background; one step away from `canvas` so it reads as chrome.
    static let surfaceSunken = color(light: 0xEBEBE8, dark: 0x0A0A0A)
    /// Main content area behind lists and dashboard panels.
    static let canvas = color(light: 0xF4F4F2, dark: 0x111111)
    /// Raised panels: cards, inputs, popovers, the detail panel.
    static let surface = color(light: 0xFFFFFF, dark: 0x1A1A1A)
    /// Hovered and selected rows. Selection is neutral, never tinted.
    static let surfaceHover = color(light: 0xE6E6E3, dark: 0x252525)

    // MARK: Lines

    /// Hairline dividers and panel borders.
    static let line = color(light: 0xE0E0DC, dark: 0x2A2A2A)
    /// Checkbox rings and input borders that must be seen (3:1 on surface and canvas).
    static let lineStrong = color(light: 0x8A8A85, dark: 0x6F6F6C)

    // MARK: Text and icons

    /// Primary text and icons.
    static let ink = color(light: 0x151515, dark: 0xF2F2EF)
    /// Secondary text: descriptions, counts, times, labels (4.5:1 or better).
    static let inkMuted = color(light: 0x5C5C58, dark: 0xA3A3A0)
    /// Placeholders and completed titles only; below 4.5:1 by design.
    static let inkFaint = color(light: 0x8A8A85, dark: 0x6F6F6C)

    // MARK: Accent and states

    /// The one accent. Fills only (primary action); never text or a thin line on light grounds.
    static let accent = color(light: 0xF5C518, dark: 0xF5C518)
    /// Text and glyphs on an `accent` fill.
    static let onAccent = color(light: 0x151515, dark: 0x151515)
    /// Keyboard focus outline: ink on light, yellow on dark.
    static let focusRing = color(light: 0x151515, dark: 0xF5C518)
    /// Destructive actions only, always next to the word Delete.
    static let danger = color(light: 0xB42318, dark: 0xFF7A66)

    // MARK: Helpers

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }))
    }
}

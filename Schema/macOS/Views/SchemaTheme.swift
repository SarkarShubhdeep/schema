//
//  SchemaTheme.swift
//  Schema
//

import AppKit
import SwiftUI

enum SchemaTheme {
    static let background = dynamicColor(
        light: (0.98, 0.98, 0.99),
        dark: (0.11, 0.11, 0.12)
    )
    static let surface = dynamicColor(
        light: (1.0, 1.0, 1.0),
        dark: (0.16, 0.16, 0.17)
    )
    static let accent = dynamicColor(
        light: (0.39, 0.40, 0.95),
        dark: (0.52, 0.53, 0.98)
    )
    static let completed = dynamicColor(
        light: (0.61, 0.64, 0.69),
        dark: (0.50, 0.52, 0.56)
    )
    static let divider = dynamicColor(
        light: (0.90, 0.91, 0.92),
        dark: (0.28, 0.28, 0.30)
    )
    static let mutedText = dynamicColor(
        light: (0.55, 0.57, 0.60),
        dark: (0.62, 0.64, 0.67)
    )
    static let tabInactive = dynamicColor(
        light: (0.75, 0.77, 0.82),
        dark: (0.52, 0.54, 0.58)
    )
    static let countBadgeBackground = dynamicColor(
        light: (0.93, 0.93, 0.94),
        dark: (0.22, 0.22, 0.24)
    )
    static let controlFill = dynamicColor(
        light: (0.95, 0.95, 0.96),
        dark: (0.20, 0.20, 0.22)
    )
    static let newListCardFill = dynamicColor(
        light: (0.96, 0.96, 0.97),
        dark: (0.15, 0.15, 0.16)
    )
    static let rowHover = dynamicColor(
        light: (0.0, 0.0, 0.0),
        dark: (1.0, 1.0, 1.0)
    )

    static func listColorName(for list: SchemaList) -> SchemaListColorName {
        if let stored = list.accentColorName,
           let color = SchemaListColorName(rawValue: stored) {
            return color
        }
        return SchemaListColorName.fallback(for: list.title)
    }

    static func listAccent(for list: SchemaList) -> Color {
        listColorName(for: list).accentColor
    }

    static func listTagBackground(for list: SchemaList) -> Color {
        listColorName(for: list).tagBackgroundColor
    }

    static func listTagForeground(for list: SchemaList) -> Color {
        listColorName(for: list).tagForegroundColor
    }

    static func tabColor(for list: SchemaList, isSelected: Bool) -> Color {
        if list.isEverythingList {
            return isSelected ? .primary : tabInactive
        }
        return listAccent(for: list).opacity(isSelected ? 1.0 : 0.72)
    }

    static func listCardBackground(for list: SchemaList) -> Color {
        listColorName(for: list).cardBackgroundColor
    }

    static func listCardForeground(for list: SchemaList) -> Color {
        listColorName(for: list).cardForegroundColor
    }

    static func rowHoverBackground(opacity: Double = 0.04) -> Color {
        rowHover.opacity(opacity)
    }

    private static func dynamicColor(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(
            nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let rgb = isDark ? dark : light
                return NSColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            })
        )
    }
}

extension SchemaListColorName {
    var accentColor: Color {
        switch self {
        case .neutral:
            Color.primary
        case .grey:
            SchemaTheme.dynamicListAccent(
                light: (0.55, 0.57, 0.60),
                dark: (0.62, 0.64, 0.67)
            )
        case .blue:
            SchemaTheme.dynamicListAccent(
                light: (0.39, 0.55, 0.95),
                dark: (0.52, 0.65, 0.98)
            )
        case .purple:
            SchemaTheme.dynamicListAccent(
                light: (0.62, 0.45, 0.92),
                dark: (0.72, 0.58, 0.98)
            )
        case .green:
            SchemaTheme.dynamicListAccent(
                light: (0.35, 0.72, 0.52),
                dark: (0.45, 0.82, 0.62)
            )
        case .orange:
            SchemaTheme.dynamicListAccent(
                light: (0.95, 0.58, 0.32),
                dark: (0.98, 0.68, 0.42)
            )
        }
    }

    var tagBackgroundColor: Color {
        accentColor.opacity(0.14)
    }

    var tagForegroundColor: Color {
        accentColor.opacity(0.95)
    }

    var cardBackgroundColor: Color {
        switch self {
        case .neutral, .grey:
            SchemaTheme.surface
        default:
            accentColor.opacity(0.12)
        }
    }

    var cardForegroundColor: Color {
        switch self {
        case .neutral, .grey:
            Color.primary
        default:
            accentColor.opacity(0.9)
        }
    }
}

private extension SchemaTheme {
    static func dynamicListAccent(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        dynamicColor(light: light, dark: dark)
    }
}

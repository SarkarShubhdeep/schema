//
//  SchemaTheme.swift
//  Schema
//

import SwiftUI

enum SchemaTheme {
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let surface = Color.white
    static let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    static let completed = Color(red: 0.61, green: 0.64, blue: 0.69)
    static let divider = Color(red: 0.90, green: 0.91, blue: 0.92)
    static let mutedText = Color(red: 0.55, green: 0.57, blue: 0.60)
    static let tabInactive = Color(red: 0.75, green: 0.77, blue: 0.82)

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
        if isSelected {
            return .primary
        }
        if list.isEverythingList {
            return tabInactive
        }
        return listAccent(for: list).opacity(0.72)
    }

    static func listCardBackground(for list: SchemaList) -> Color {
        listColorName(for: list).cardBackgroundColor
    }

    static func listCardForeground(for list: SchemaList) -> Color {
        listColorName(for: list).cardForegroundColor
    }

    static let countBadgeBackground = Color(red: 0.93, green: 0.93, blue: 0.94)
}

extension SchemaListColorName {
    var accentColor: Color {
        switch self {
        case .neutral:
            Color.primary
        case .grey:
            Color(red: 0.55, green: 0.57, blue: 0.60)
        case .blue:
            Color(red: 0.39, green: 0.55, blue: 0.95)
        case .purple:
            Color(red: 0.62, green: 0.45, blue: 0.92)
        case .green:
            Color(red: 0.35, green: 0.72, blue: 0.52)
        case .orange:
            Color(red: 0.95, green: 0.58, blue: 0.32)
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
            Color.white
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

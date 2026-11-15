//
//  SchemaFont.swift
//  Schema
//
//  Type styles from the Schema design system
//  (https://claude.ai/artifact/5fDFJNPDcbr1nWJwyGSG9L).
//  Space Grotesk: titles, numbers, times, counts, badges, labels.
//  Satoshi: task titles, body text, buttons and menus.
//

import CoreText
import Foundation
import SwiftUI

enum SchemaFont {
    static let displayFamily = "Space Grotesk"
    static let textFamily = "Satoshi"

    /// Registers the bundled font files for this process. Call once at launch.
    static func registerBundledFonts() {
        let urls = ["ttf", "otf"].flatMap { ext in
            (Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
                + (Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? [])
        }
        for url in Set(urls) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Space Grotesk at a custom size. Scales with Dynamic Type relative to `style`.
    static func spaceGrotesk(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(SchemaFont.displayFamily, size: size, relativeTo: style).weight(weight)
    }

    /// Satoshi at a custom size. Scales with Dynamic Type relative to `style`.
    static func satoshi(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(SchemaFont.textFamily, size: size, relativeTo: style).weight(weight)
    }

    // MARK: Design system styles, Space Grotesk

    /// Once per screen: the dashboard date or the open page's title.
    static let schemaDisplay = spaceGrotesk(32, weight: .semibold, relativeTo: .largeTitle)
    /// Panel and section headings.
    static let schemaTitle = spaceGrotesk(18, weight: .semibold, relativeTo: .headline)
    /// Timers and countdowns.
    static let schemaCountdown = spaceGrotesk(56, weight: .medium, relativeTo: .largeTitle).monospacedDigit()
    /// Stat tile figures.
    static let schemaNumeral = spaceGrotesk(28, weight: .medium, relativeTo: .title).monospacedDigit()
    /// Times, dates and counts beside rows, and keyboard keys.
    static let schemaMeta = spaceGrotesk(12, weight: .medium, relativeTo: .caption).monospacedDigit()
    /// Count badges and status chips.
    static let schemaBadge = spaceGrotesk(11, weight: .semibold, relativeTo: .caption2).monospacedDigit()
    /// Uppercase section labels; pair with `.textCase(.uppercase)` and `.tracking(0.9)`.
    static let schemaLabel = spaceGrotesk(11, weight: .semibold, relativeTo: .caption2)

    // MARK: Design system styles, Satoshi

    /// Task titles in rows.
    static let schemaTask = satoshi(15, weight: .medium, relativeTo: .body)
    /// Descriptions, notes, settings copy.
    static let schemaBody = satoshi(14, weight: .regular, relativeTo: .body)
    /// Buttons, sidebar items, menus.
    static let schemaControl = satoshi(13, weight: .medium, relativeTo: .callout)
    /// Helper text.
    static let schemaCaption = satoshi(12, weight: .regular, relativeTo: .caption)
}

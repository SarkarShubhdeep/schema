//
//  SchemaLabels.swift
//  Schema
//
//  Small static labels: chips, count badges and keyboard hints. They use
//  6px corners (badges are pills) so they read as labels, not buttons.
//

import SwiftUI

// MARK: - Chip

enum SchemaChipStyle {
    /// Soft grey fill: list tags, parsed @mentions.
    case soft
    /// Hairline border, no fill: quiet status ("Needs reply").
    case outline
}

struct SchemaChip: View {
    let text: String
    var systemImage: String?
    var style: SchemaChipStyle = .soft

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.schemaBadge)
                .lineLimit(1)
        }
        .fixedSize()
        .foregroundStyle(SchemaTheme.inkMuted)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(style == .soft ? SchemaTheme.surfaceHover : .clear)
        )
        .overlay {
            if style == .outline {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(SchemaTheme.line, lineWidth: 1)
            }
        }
    }
}

// MARK: - Count badge

struct SchemaBadge: View {
    let count: Int
    /// Ink fill for counts that need attention (unread); soft grey otherwise.
    var isProminent = false

    var body: some View {
        Text("\(count)")
            .font(.schemaBadge)
            .foregroundStyle(isProminent ? SchemaTheme.canvas : SchemaTheme.inkMuted)
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(
                Capsule(style: .continuous)
                    .fill(isProminent ? SchemaTheme.ink : SchemaTheme.surfaceHover)
            )
            .accessibilityLabel("\(count)")
    }
}

// MARK: - Keyboard hint

/// A keyboard shortcut shown next to the action it triggers ("N", "⌘K").
struct SchemaKeyHint: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(SchemaTheme.inkMuted)
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(SchemaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(SchemaTheme.line, lineWidth: 1)
            )
            .accessibilityLabel("Shortcut \(keys)")
    }
}

// MARK: - Section label

/// Uppercase section heading in Space Grotesk ("LISTS", "COMPLETED").
struct SchemaSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.schemaLabel)
            .textCase(.uppercase)
            .tracking(0.9)
            .foregroundStyle(SchemaTheme.inkMuted)
            .lineLimit(1)
    }
}

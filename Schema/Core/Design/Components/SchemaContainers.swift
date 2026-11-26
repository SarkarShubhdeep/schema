//
//  SchemaContainers.swift
//  Schema
//
//  Cards (16px corners, hairline border) and the flat progress bar.
//

import SwiftUI

// MARK: - Card

struct SchemaCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    var fill: Color = SchemaTheme.surface
    var bordered = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(bordered ? SchemaTheme.line : .clear, lineWidth: 1)
            )
    }
}

extension View {
    /// A surface card: panels, stat tiles, task groups, dialogs.
    func schemaCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16, fill: Color = SchemaTheme.surface, bordered: Bool = true) -> some View {
        modifier(SchemaCardModifier(padding: padding, cornerRadius: cornerRadius, fill: fill, bordered: bordered))
    }
}

// MARK: - Progress bar

/// A thin, flat, rounded bar. Ink fill on a soft grey track; no gradients or waves.
struct SchemaProgressBar: View {
    /// 0...1
    let value: Double
    var height: CGFloat = 6
    var accessibilityText: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(SchemaTheme.surfaceHover)
                Capsule(style: .continuous)
                    .fill(SchemaTheme.ink)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .animation(SchemaMotion.smooth, value: value)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText ?? "Progress")
        .accessibilityValue("\(Int((max(0, min(1, value)) * 100).rounded())) percent")
    }
}

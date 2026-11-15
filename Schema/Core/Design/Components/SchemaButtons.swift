//
//  SchemaButtons.swift
//  Schema
//
//  Pill buttons and round icon buttons. Things you press are fully rounded;
//  yellow (`.primary`) is for the one main action on a screen.
//

import SwiftUI

// MARK: - Pill button

enum SchemaButtonKind {
    /// Yellow fill. At most one per view.
    case primary
    /// Surface fill with a hairline border: menus, toggles, secondary actions.
    case secondary
    /// No fill until hovered: navigation and low-weight actions.
    case ghost
    /// Red text, no fill. Only for Delete, always with the word.
    case danger
    /// Ink fill: confirmations inside a dark or busy context (e.g. the selection toolbar's neighbours).
    case ink
}

enum SchemaButtonSize {
    case regular
    case small

    var height: CGFloat { self == .regular ? 34 : 28 }
    var horizontalPadding: CGFloat { self == .regular ? 16 : 12 }
    var font: Font { self == .regular ? .schemaControl : .satoshi(12, weight: .medium, relativeTo: .caption) }
}

struct SchemaButtonStyle: ButtonStyle {
    var kind: SchemaButtonKind = .secondary
    var size: SchemaButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        SchemaButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

private struct SchemaButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: SchemaButtonKind
    let size: SchemaButtonSize

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(size.font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(foreground)
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(Capsule(style: .continuous).fill(background))
            .overlay {
                if kind == .secondary {
                    Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(SchemaMotion.fast, value: isHovered)
            .animation(SchemaMotion.fast, value: configuration.isPressed)
            .onHover { isHovered = $0 && isEnabled }
    }

    private var foreground: Color {
        switch kind {
        case .primary: SchemaTheme.onAccent
        case .secondary, .ghost: SchemaTheme.ink
        case .danger: SchemaTheme.danger
        case .ink: SchemaTheme.canvas
        }
    }

    private var background: Color {
        switch kind {
        case .primary: isHovered ? SchemaTheme.accent.opacity(0.88) : SchemaTheme.accent
        case .secondary: isHovered ? SchemaTheme.surfaceHover : SchemaTheme.surface
        case .ghost, .danger: isHovered ? SchemaTheme.surfaceHover : .clear
        case .ink: isHovered ? SchemaTheme.ink.opacity(0.85) : SchemaTheme.ink
        }
    }
}

extension ButtonStyle where Self == SchemaButtonStyle {
    static func schema(_ kind: SchemaButtonKind = .secondary, size: SchemaButtonSize = .regular) -> SchemaButtonStyle {
        SchemaButtonStyle(kind: kind, size: size)
    }
}

// MARK: - Round icon button

/// A round, icon-only button. `label` is read by VoiceOver and shown with the
/// shortcut in the hover tooltip ("Settings  ⌘,"), so no visible text is needed.
struct SchemaIconButton: View {
    let systemImage: String
    let label: String
    var shortcut: String?
    var size: CGFloat = 32
    var isFilled = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(isHovered || isFilled ? SchemaTheme.ink : SchemaTheme.inkMuted)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(isFilled ? SchemaTheme.surface : (isHovered ? SchemaTheme.surfaceHover : .clear))
                )
                .overlay {
                    if isFilled {
                        Circle().strokeBorder(SchemaTheme.line, lineWidth: 1)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(SchemaMotion.fast, value: isHovered)
        .onHover { isHovered = $0 && isEnabled }
        .help(tooltip)
        .accessibilityLabel(label)
    }

    private var tooltip: String {
        guard let shortcut, !shortcut.isEmpty else { return label }
        return "\(label)  \(shortcut)"
    }
}

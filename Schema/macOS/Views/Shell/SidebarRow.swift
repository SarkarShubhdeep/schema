//
//  SidebarRow.swift
//  Schema
//
//  One sidebar item, and the section header between groups. Rows fill the
//  sidebar island's width, with its 8pt inner corners (#116).
//

import SwiftUI

enum SidebarMetrics {
    /// Space before the icon inside a row.
    static let iconLeading: CGFloat = 12
    static let rowHeight: CGFloat = 36
    static let iconSize: CGFloat = 14
}

enum SidebarRowTrailing {
    case count(Int)
    case keys(String)
    /// A short live value, like a timer's time left.
    case text(String)
    case none
}

struct SidebarRow<Icon: View>: View {
    let title: String
    let isActive: Bool
    var isSubtle = false
    let trailing: SidebarRowTrailing
    let tooltip: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)

                Text(title)
                    .font(.schemaControl)
                    .lineLimit(1)
                Spacer(minLength: 6)
                trailingView
                    .fixedSize()
            }
            .foregroundStyle(foreground)
            .padding(.leading, SidebarMetrics.iconLeading)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: SidebarMetrics.rowHeight)
            .background(RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous).fill(background))
            .contentShape(RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help(tooltip)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .count(let count):
            if count > 0 {
                Text("\(count)")
                    .font(.schemaMeta)
                    .opacity(isActive ? 0.75 : 1)
            }
        case .keys(let keys):
            Text(keys)
                .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isActive ? SchemaTheme.canvas.opacity(0.35) : SchemaTheme.line, lineWidth: 1)
                )
                .opacity(isActive ? 0.75 : 1)
                .accessibilityHidden(true)
        case .text(let text):
            Text(text)
                .font(.schemaMeta)
                .lineLimit(1)
                .fixedSize()
                .opacity(isActive ? 0.75 : 1)
        case .none:
            EmptyView()
        }
    }

    private var foreground: Color {
        if isActive { return SchemaTheme.canvas }
        if isSubtle { return isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted }
        return isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted
    }

    private var background: Color {
        if isActive { return SchemaTheme.ink }
        return isHovered ? SchemaTheme.surfaceHover : .clear
    }
}

/// Group heading: an uppercase label and an optional trailing button.
struct SidebarSectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack {
            SchemaSectionLabel(title)
                .fixedSize()
            Spacer(minLength: 8)
            accessory()
        }
        .padding(.leading, SidebarMetrics.iconLeading)
        .frame(height: 30)
        .padding(.top, 6)
    }
}

extension SidebarSectionHeader where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

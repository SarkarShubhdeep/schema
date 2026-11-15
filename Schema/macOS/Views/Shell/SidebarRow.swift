//
//  SidebarRow.swift
//  Schema
//
//  One sidebar item, and the section header between groups. Collapsing the
//  sidebar only changes its width: rows keep their height, icons stay where
//  they are, and labels are clipped by the narrowing edge as they fade.
//  The open sidebar and the rail are the same views.
//

import SwiftUI

enum SidebarMetrics {
    /// Horizontal inset of rows from the sidebar edges.
    static func rowInset(collapsed: Bool) -> CGFloat { collapsed ? 18 : 12 }
    /// Space before the icon inside a row. Inset + this stays 29, so icons don't move.
    static func iconLeading(collapsed: Bool) -> CGFloat { collapsed ? 11 : 17 }
    static let rowHeight: CGFloat = 36
    static let iconSize: CGFloat = 14
    /// Width of a row's content in the open sidebar; collapsed rows clip it.
    static let contentWidth = ShellMetrics.sidebarWidth - 2 * 12
    static let fadeOut = Animation.easeOut(duration: 0.12)
}

enum SidebarRowTrailing {
    case count(Int)
    case keys(String)
    case none
}

struct SidebarRow<Icon: View>: View {
    let title: String
    let isActive: Bool
    let isCollapsed: Bool
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

                Group {
                    Text(title)
                        .font(.schemaControl)
                        .lineLimit(1)
                        .fixedSize()
                    Spacer(minLength: 6)
                    trailingView
                        .fixedSize()
                }
                .opacity(isCollapsed ? 0 : 1)
            }
            .foregroundStyle(foreground)
            .padding(.leading, SidebarMetrics.iconLeading(collapsed: isCollapsed))
            .padding(.trailing, 10)
            .frame(width: SidebarMetrics.contentWidth, alignment: .leading)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .frame(height: SidebarMetrics.rowHeight)
            .background(Capsule(style: .continuous).fill(background))
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
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

/// Group heading. Open: an uppercase label (and an optional trailing button).
/// Collapsed: a short divider in the same slot, so nothing below shifts.
struct SidebarSectionHeader<Accessory: View>: View {
    let title: String
    let isCollapsed: Bool
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        ZStack(alignment: .leading) {
            HStack {
                SchemaSectionLabel(title)
                    .fixedSize()
                Spacer(minLength: 8)
                accessory()
            }
            .padding(.leading, SidebarMetrics.iconLeading(collapsed: isCollapsed) - 5)
            .frame(width: SidebarMetrics.contentWidth, alignment: .leading)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .clipped()
            .opacity(isCollapsed ? 0 : 1)
            .allowsHitTesting(!isCollapsed)

            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 24, height: 1)
                .frame(maxWidth: .infinity)
                .opacity(isCollapsed ? 1 : 0)
        }
        .frame(height: 30)
        .padding(.top, 6)
    }
}

extension SidebarSectionHeader where Accessory == EmptyView {
    init(title: String, isCollapsed: Bool) {
        self.init(title: title, isCollapsed: isCollapsed) { EmptyView() }
    }
}

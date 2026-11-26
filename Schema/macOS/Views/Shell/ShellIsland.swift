//
//  ShellIsland.swift
//  Schema
//
//  The pieces of the window grid (#116): an island (a rounded surface with
//  8pt padding), the header island every page puts at its top, and the
//  room a collapsed side panel takes in that header row.
//

import SwiftUI

extension View {
    /// A floating island: 8pt padding and a 16pt corner on the island fill.
    func shellIsland() -> some View {
        padding(ShellMetrics.islandPadding)
            .background(
                RoundedRectangle(cornerRadius: ShellMetrics.islandRadius, style: .continuous)
                    .fill(SchemaTheme.island)
            )
    }
}

/// How far a page's header island stays from the collapsed panels beside
/// it: the sidebar pill on the left, the details button on the right.
struct ShellHeaderInsets: Equatable {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0
}

extension EnvironmentValues {
    @Entry var shellHeaderInsets = ShellHeaderInsets()
}

/// The island at the top of every page: where you are (up to ⅔ of the
/// width), then the page's actions on the right.
struct HeaderIsland<Leading: View, Trailing: View>: View {
    @Environment(\.shellHeaderInsets) private var insets

    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HeaderSplitLayout {
            HStack(spacing: 6) {
                leading()
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ShellMetrics.innerGap) {
                trailing()
            }
            .fixedSize()
        }
        .font(.satoshi(14, weight: .medium, relativeTo: .callout))
        .foregroundStyle(SchemaTheme.inkMuted)
        .frame(height: ShellMetrics.control)
        .shellIsland()
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
    }
}

/// Two children: the first gets up to ⅔ of the width, the second its own
/// width at the trailing edge.
private struct HeaderSplitLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? ShellMetrics.contentWidth, height: ShellMetrics.control)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let gap = ShellMetrics.innerGap
        let trailingWidth = min(subviews[1].sizeThatFits(.unspecified).width, bounds.width)
        let leadingWidth = max(0, min(bounds.width * 2 / 3, bounds.width - trailingWidth - gap))
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
            proposal: ProposedViewSize(width: leadingWidth, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
            proposal: ProposedViewSize(width: trailingWidth, height: bounds.height)
        )
    }
}

/// The 44pt square buttons in island headers and footers: a quiet icon,
/// an 8pt-corner hover fill, and a tooltip with the shortcut.
struct IslandIconButton: View {
    let systemImage: String
    let label: String
    var shortcut: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted)
                .frame(width: ShellMetrics.control, height: ShellMetrics.control)
                .background(
                    RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous)
                        .fill(isHovered ? SchemaTheme.surfaceHover : .clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help(shortcut.map { "\(label)  \($0)" } ?? label)
        .accessibilityLabel(label)
    }
}

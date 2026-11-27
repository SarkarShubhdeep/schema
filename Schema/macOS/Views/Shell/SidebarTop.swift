//
//  SidebarTop.swift
//  Schema
//
//  The top of the sidebar (#120): Search (⌘K) and the Today tile, which
//  is its own place, not a page and not a section.
//

import SwiftUI

/// Opens the command bar (#122).
struct SidebarSearchPill: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                Text("Search")
                    .font(.schemaBody)
                Spacer(minLength: 4)
                Text("⌘K")
                    .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .padding(.horizontal, 6)
                    .frame(minHeight: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(SchemaTheme.line, lineWidth: 1)
                    )
            }
            .foregroundStyle(isHovered ? SchemaTheme.inkMuted : SchemaTheme.inkFaint)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(height: 36)
            .background(Capsule(style: .continuous).fill(SchemaTheme.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help("Search everything  ⌘K")
        .accessibilityLabel("Search everything")
    }
}

/// Today as a tile: the date, the next reminder and how many tasks are due.
/// Dark while Today is open.
struct SidebarTodayTile: View {
    let isActive: Bool
    let openCount: Int
    let nextReminder: Date?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? SchemaTheme.canvas.opacity(0.14) : SchemaTheme.island)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today")
                        .font(.spaceGrotesk(16, weight: .semibold, relativeTo: .headline))
                    Text(subtitle)
                        .font(.schemaCaption)
                        .lineLimit(1)
                        .opacity(0.7)
                }
                Spacer(minLength: 4)
                Text("\(openCount)")
                    .font(.spaceGrotesk(20, weight: .semibold, relativeTo: .title3).monospacedDigit())
            }
            .foregroundStyle(isActive ? SchemaTheme.canvas : SchemaTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? SchemaTheme.ink : (isHovered ? SchemaTheme.surfaceHover : SchemaTheme.islandCard))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .help("Today")
        .accessibilityLabel("Today, \(openCount) open. \(subtitle)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var subtitle: String {
        let day = Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        guard let nextReminder else { return day }
        return "\(day) · next at \(nextReminder.formatted(date: .omitted, time: .shortened))"
    }
}

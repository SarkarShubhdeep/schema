//
//  PomodoroParts.swift
//  Schema
//
//  Small pieces the Pomodoro page shares (#89): the clock text, the heat
//  map's grey shades, the choice pills and the sidebar row.
//

import SwiftData
import SwiftUI

enum PomodoroText {
    /// "18:42", or "1:05:00" from an hour up.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, rest) }
        return String(format: "%02d:%02d", minutes, rest)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

enum PomodoroShade {
    /// Grey squares only: yellow stays on New timer. 0 is an empty square.
    static func fill(level: Int) -> Color {
        switch level {
        case ..<1: SchemaTheme.surfaceSunken
        case 1: SchemaTheme.ink.opacity(0.2)
        case 2: SchemaTheme.ink.opacity(0.4)
        case 3: SchemaTheme.ink.opacity(0.64)
        default: SchemaTheme.ink.opacity(0.88)
        }
    }
}

/// A square of the heat map.
struct PomodoroSquare: View {
    let level: Int
    var size: CGFloat = 18
    var radius: CGFloat = 5

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(PomodoroShade.fill(level: level))
            .frame(width: size, height: size)
    }
}

/// A pill in a group of choices: the chosen one has a soft grey fill.
struct PomodoroChoiceStyle: ButtonStyle {
    let isOn: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.satoshi(12, weight: .medium, relativeTo: .caption))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(isOn || isHovered ? SchemaTheme.ink : SchemaTheme.inkMuted)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule(style: .continuous).fill(isOn ? SchemaTheme.surfaceHover : (isHovered ? SchemaTheme.surfaceHover.opacity(0.5) : .clear)))
            .overlay(Capsule(style: .continuous).strokeBorder(isOn ? .clear : SchemaTheme.line, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onHover { isHovered = $0 }
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Pomodoro under Views, with the time left on the timer that ends soonest.
struct PomodoroSidebarRow: View {
    let isActive: Bool
    let action: () -> Void

    @Query private var timers: [PomodoroTimer]

    var body: some View {
        if timers.contains(where: \.isRunning) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                row(trailing: soonest(at: context.date))
            }
        } else {
            row(trailing: .none)
        }
    }

    private func row(trailing: SidebarRowTrailing) -> some View {
        SidebarRow(title: "Pomodoro", isActive: isActive, trailing: trailing, tooltip: "Pomodoro") {
            Image(systemName: "timer")
        } action: {
            action()
        }
    }

    private func soonest(at now: Date) -> SidebarRowTrailing {
        let left = timers.filter(\.isRunning).map { PomodoroEngine.remaining($0, at: now) }.min()
        return left.map { .text(PomodoroText.clock($0)) } ?? .none
    }
}

/// A horizontal scroll row with no scrollbar. Where content runs past an
/// edge, that edge fades out softly, so the heat map dissolves instead of
/// being cut off; an edge with nothing hidden stays crisp.
struct FadingHorizontalScroll<Content: View>: View {
    var fade: CGFloat = 40
    var startsAtTrailingEdge = false
    @ViewBuilder let content: Content

    @State private var hidden = FadingHorizontalScrollEdges()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
        }
        .defaultScrollAnchor(startsAtTrailingEdge ? .trailing : .leading)
        .modifier(HiddenEdgesReader(hidden: $hidden))
        .mask {
            HStack(spacing: 0) {
                edge(from: .leading).frame(width: hidden.leading ? fade : 0)
                Rectangle()
                edge(from: .trailing).frame(width: hidden.trailing ? fade : 0)
            }
        }
        .animation(SchemaMotion.fast, value: hidden)
    }

    /// Clear at the outer edge, solid toward the middle, eased so it reads as a soft blur.
    private func edge(from side: HorizontalEdge) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.35), location: 0.4),
                .init(color: .black, location: 1),
            ],
            startPoint: side == .leading ? .leading : .trailing,
            endPoint: side == .leading ? .trailing : .leading
        )
    }
}

/// Which edges of a horizontal scroll view have content beyond them.
private struct HiddenEdgesReader: ViewModifier {
    @Binding var hidden: FadingHorizontalScrollEdges

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.onScrollGeometryChange(for: FadingHorizontalScrollEdges.self) { geometry in
                let offset = geometry.contentOffset.x + geometry.contentInsets.leading
                return FadingHorizontalScrollEdges(
                    leading: offset > 1,
                    trailing: offset + geometry.containerSize.width < geometry.contentSize.width - 1
                )
            } action: { _, edges in
                hidden = edges
            }
        } else {
            content
        }
    }
}

struct FadingHorizontalScrollEdges: Equatable {
    var leading = false
    var trailing = false
}

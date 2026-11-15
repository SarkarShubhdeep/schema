//
//  SchemaCheckbox.swift
//  Schema
//
//  The quiet task checkbox: a grey ring when open, a ring with a simple grey
//  check when done, a dashed ring when blocked by routine order. No yellow,
//  no decorative shapes; a small press is the only flourish.
//

import SwiftUI

struct SchemaCheckbox: View {
    let isChecked: Bool
    var isBlocked = false
    var size: CGFloat = 18
    /// VoiceOver name of the task, e.g. "Pick up dry cleaning".
    var label: String = ""
    /// Extra clickable space around the ring (does not change its size).
    var hitPadding: CGFloat = 6
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var pressScale: CGFloat = 1

    var body: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .strokeBorder(
                        ringColor,
                        style: StrokeStyle(lineWidth: 1.5, dash: isBlocked && !isChecked ? [2.5, 2.5] : [])
                    )
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .transition(.opacity)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(pressScale)
            .padding(hitPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBlocked && !isChecked)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isHovered)
        .animation(SchemaMotion.animation(SchemaMotion.fast, reduceMotion: reduceMotion), value: isChecked)
        .help(isBlocked && !isChecked ? "Complete the previous task in the sequence first" : "")
        .accessibilityLabel(label.isEmpty ? "Task" : label)
        .accessibilityValue(isChecked ? "Completed" : (isBlocked ? "Blocked" : "Not completed"))
        .accessibilityAddTraits(.isButton)
    }

    private var ringColor: Color {
        if isChecked { return SchemaTheme.inkFaint }
        if isBlocked { return SchemaTheme.lineStrong.opacity(0.6) }
        return isHovered ? SchemaTheme.ink : SchemaTheme.lineStrong
    }

    private func toggle() {
        guard !reduceMotion else {
            action()
            return
        }
        withAnimation(SchemaMotion.spring) { pressScale = 0.94 }
        action()
        withAnimation(SchemaMotion.spring.delay(0.08)) { pressScale = 1 }
    }
}

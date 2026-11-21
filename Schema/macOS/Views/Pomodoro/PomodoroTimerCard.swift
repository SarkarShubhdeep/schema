//
//  PomodoroTimerCard.swift
//  Schema
//
//  One running timer (#89): its phase, a large countdown, a thin progress
//  bar, when it ends, today's finished sessions, and its controls.
//

import SwiftUI

struct PomodoroTimerCard: View {
    let timer: PomodoroTimer
    /// Focus minutes of each session this timer finished today, oldest first.
    let todaySessions: [Int]
    let linkedPage: SchemaList?
    /// Space pauses or resumes this timer.
    let isSpaceTarget: Bool
    let onOpenPage: (SchemaList) -> Void

    @Environment(PomodoroRunner.self) private var runner
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isConfirmingRemove = false

    var body: some View {
        Group {
            if timer.isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(now: context.date)
                }
            } else {
                content(now: .now)
            }
        }
        .schemaCard(padding: 18)
        .alert("Rename timer", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Rename") { runner.rename(timer, to: newName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Stop \u{201C}\(timer.name)\u{201D}?", isPresented: $isConfirmingRemove) {
            Button("Stop and remove", role: .destructive) { runner.remove(timer) }
        } message: {
            Text("The sessions it finished stay in your focus history.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(timer.name)
    }

    private func content(now: Date) -> some View {
        let remaining = PomodoroEngine.remaining(timer, at: now)
        let isWaiting = PomodoroEngine.isWaiting(timer)
        let isActiveFocus = timer.isRunning && timer.phase == .focus
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.name)
                        .font(.satoshi(15, weight: .bold, relativeTo: .headline))
                        .foregroundStyle(SchemaTheme.ink)
                        .lineLimit(1)
                    Text(plan)
                        .font(.schemaMeta)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                phaseBadge(isWaiting: isWaiting)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(PomodoroText.clock(remaining))
                    .font(.spaceGrotesk(48, weight: .medium, relativeTo: .largeTitle).monospacedDigit())
                    .foregroundStyle(timer.isRunning ? SchemaTheme.ink : SchemaTheme.inkMuted)
                    .lineLimit(1)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("\(PomodoroText.clock(remaining)) left")
                progressBar(PomodoroEngine.progress(timer, at: now), isActive: isActiveFocus)
                Text(nextLine(remaining: remaining, now: now, isWaiting: isWaiting))
                    .font(.schemaMeta)
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .lineLimit(1)
            }

            if let linkedPage {
                Button { onOpenPage(linkedPage) } label: {
                    SchemaChip(text: linkedPage.title, systemImage: linkedPage.pageKind.systemImage)
                }
                .buttonStyle(.plain)
                .help("Open \(linkedPage.title)")
            }

            controls(isWaiting: isWaiting)
        }
    }

    private var plan: String {
        timer.breakMinutes > 0
            ? "\(timer.focusMinutes) min focus · \(timer.breakMinutes) min break"
            : "\(timer.focusMinutes) min focus · no break"
    }

    private func phaseBadge(isWaiting: Bool) -> some View {
        let title = isWaiting ? "Ready" : (!timer.isRunning ? "Paused" : (timer.phase == .focus ? "Focus" : "Break"))
        let isFocus = timer.isRunning && timer.phase == .focus
        return Text(title.uppercased())
            .font(.schemaBadge)
            .tracking(0.66)
            .foregroundStyle(timer.isRunning ? SchemaTheme.ink : SchemaTheme.inkMuted)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(isFocus ? SchemaTheme.surfaceHover : .clear))
            .overlay {
                if !isFocus {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1)
                }
            }
            .fixedSize()
    }

    private func progressBar(_ value: Double, isActive: Bool) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(SchemaTheme.surfaceSunken)
                Capsule(style: .continuous)
                    .fill(isActive ? SchemaTheme.ink : SchemaTheme.lineStrong)
                    .frame(width: value * proxy.size.width)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private func nextLine(remaining: TimeInterval, now: Date, isWaiting: Bool) -> String {
        if isWaiting {
            return timer.phase == .rest ? "Ready for a \(timer.breakMinutes) min break" : "Ready for the next session"
        }
        guard timer.isRunning else { return "Paused" }
        let end = PomodoroText.time(now.addingTimeInterval(remaining))
        switch timer.phase {
        case .focus:
            return timer.breakMinutes > 0 ? "Ends at \(end), then a \(timer.breakMinutes) min break" : "Ends at \(end), then the next session"
        case .rest:
            return "Break ends at \(end), then focus"
        }
    }

    private func controls(isWaiting: Bool) -> some View {
        let playLabel = timer.isRunning ? "Pause" : (isWaiting ? "Start" : "Resume")
        return HStack(spacing: 8) {
            SchemaIconButton(
                systemImage: timer.isRunning ? "pause.fill" : "play.fill",
                label: playLabel,
                shortcut: isSpaceTarget ? "Space" : nil,
                size: 36,
                isFilled: true
            ) {
                runner.togglePause(timer)
            }

            if timer.phase == .rest {
                Button("Skip break") { runner.skipBreak(timer) }
                    .buttonStyle(.schema(.secondary, size: .small))
            } else if !isWaiting {
                Button("Finish session") { runner.finishFocus(timer) }
                    .buttonStyle(.schema(.secondary, size: .small))
                    .help("End this session now and count the minutes so far")
            }

            Spacer(minLength: 8)

            HStack(spacing: 3) {
                ForEach(Array(todaySessions.suffix(8).enumerated()), id: \.offset) { _, minutes in
                    PomodoroSquare(level: PomodoroHistory.level(forSessionMinutes: minutes), size: 10, radius: 3)
                }
            }
            .accessibilityHidden(true)
            Text("\(todaySessions.count) today")
                .font(.schemaMeta)
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
                .fixedSize()

            optionsMenu
        }
    }

    private var optionsMenu: some View {
        SchemaMenuButton("Timer options") {
            SchemaMenuItem.header(timer.name)
            SchemaMenuItem.action("Rename\u{2026}") {
                newName = timer.name
                isRenaming = true
            }
            SchemaMenuItem.submenu("Focus length") {
                for minutes in Self.lengthChoices(including: timer.focusMinutes, from: [15, 25, 30, 40, 45, 50, 60, 90]) {
                    SchemaMenuItem.action("\(minutes) min", isChecked: timer.focusMinutes == minutes) { runner.setLengths(timer, focus: minutes) }
                }
            }
            SchemaMenuItem.submenu("Break length") {
                for minutes in Self.lengthChoices(including: timer.breakMinutes, from: [0, 5, 10, 15, 20]) {
                    SchemaMenuItem.action(minutes == 0 ? "No break" : "\(minutes) min", isChecked: timer.breakMinutes == minutes) { runner.setLengths(timer, rest: minutes) }
                }
            }
            SchemaMenuItem.action("Start breaks and sessions by themselves", isChecked: timer.startsPhasesAutomatically) {
                runner.setAutomatic(timer, !timer.startsPhasesAutomatically)
            }
            SchemaMenuItem.divider
            SchemaMenuItem.action("Restart session") { runner.restartFocus(timer) }
            SchemaMenuItem.divider
            SchemaMenuItem.action("Stop and remove\u{2026}", isDestructive: true) { isConfirmingRemove = true }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.inkMuted)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .fixedSize()
        .help("Timer options")
    }

    private static func lengthChoices(including current: Int, from base: [Int]) -> [Int] {
        base.contains(current) ? base : (base + [current]).sorted()
    }
}

//
//  PomodoroHistoryView.swift
//  Schema
//
//  Focus history (#89). Week: a row per day, one square per finished
//  session (darker for longer), the running one outlined and filling up.
//  Year: one square per day, GitHub-style, darker for more focus time.
//

import SwiftUI

struct PomodoroHistoryView: View {
    enum Range { case week, year }

    let entries: [PomodoroHistory.Entry]
    let timers: [PomodoroTimer]

    @State private var range: Range = .week
    @State private var filter: UUID?

    init(entries: [PomodoroHistory.Entry], timers: [PomodoroTimer]) {
        self.entries = entries
        self.timers = timers
        #if DEBUG
        if DemoData.isEnabled, DemoData.showsPomodoroYear { _range = State(initialValue: .year) }
        #endif
    }

    /// Empty squares a day row shows: an eight-hour day of 25-minute sessions.
    private static let daySlots = 16

    var body: some View {
        let shown = filter.map { id in entries.filter { $0.timerID == id } } ?? entries
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("Focus history")
                    .font(.schemaTitle)
                    .foregroundStyle(SchemaTheme.ink)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Button("Week") { range = .week }
                        .buttonStyle(PomodoroChoiceStyle(isOn: range == .week))
                    Button("Year") { range = .year }
                        .buttonStyle(PomodoroChoiceStyle(isOn: range == .year))
                }
            }

            if !timers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button("All timers") { filter = nil }
                            .buttonStyle(PomodoroChoiceStyle(isOn: filter == nil))
                        ForEach(timers) { timer in
                            Button(timer.name) { filter = timer.id }
                                .buttonStyle(PomodoroChoiceStyle(isOn: filter == timer.id))
                        }
                    }
                }
            }

            switch range {
            case .week: week(shown)
            case .year: year(shown)
            }
        }
        .schemaCard(padding: 20)
    }

    // MARK: Week

    private func week(_ shown: [PomodoroHistory.Entry]) -> some View {
        let calendar = Calendar.current
        let running = timers.filter { $0.isRunning && $0.phase == .focus && (filter == nil || filter == $0.id) }
        return VStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(PomodoroHistory.week(shown, now: .now, calendar: calendar)) { row in
                    GridRow {
                        Text(row.isToday ? "Today" : row.day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.spaceGrotesk(13, weight: row.isToday ? .semibold : .medium, relativeTo: .callout))
                            .foregroundStyle(row.isToday ? SchemaTheme.ink : SchemaTheme.inkMuted)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: 52, alignment: .leading)
                            .help(row.day.formatted(date: .complete, time: .omitted))
                        squares(for: row, running: row.isToday ? running : [])
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(row.sessions.isEmpty ? "—" : PomodoroHistory.duration(row.totalMinutes))
                                .font(.spaceGrotesk(13, weight: .medium, relativeTo: .callout).monospacedDigit())
                                .foregroundStyle(SchemaTheme.ink)
                            Text(sessionCount(row.sessions.count))
                                .font(.satoshi(11, relativeTo: .caption2))
                                .foregroundStyle(SchemaTheme.inkMuted)
                        }
                        .lineLimit(1)
                        .fixedSize()
                        .gridColumnAlignment(.trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.isToday ? "Today" : row.day.formatted(.dateTime.weekday(.wide))): \(sessionCount(row.sessions.count)), \(PomodoroHistory.duration(row.totalMinutes))")
                }
            }
            HStack(spacing: 12) {
                Text("One square is one finished focus session. Longer sessions are darker. The outlined one is running.")
                    .font(.satoshi(12, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.inkMuted)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text("25 min")
                    ForEach([2, 3, 4], id: \.self) { PomodoroSquare(level: $0, size: 12, radius: 3) }
                    Text("50 min")
                }
                .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(SchemaTheme.inkMuted)
                .fixedSize()
                .accessibilityHidden(true)
            }
        }
    }

    private func squares(for row: PomodoroHistory.DayRow, running: [PomodoroTimer]) -> some View {
        let empties = max(0, Self.daySlots - row.sessions.count - running.count)
        return HStack(spacing: 5) {
            ForEach(Array(row.sessions.enumerated()), id: \.offset) { index, session in
                PomodoroSquare(level: PomodoroHistory.level(forSessionMinutes: session.minutes))
                    .help("\(session.timerName) · \(session.minutes) min · \(PomodoroText.time(session.startedAt))")
            }
            ForEach(running) { timer in
                RunningSquare(timer: timer)
            }
            ForEach(0..<empties, id: \.self) { _ in
                PomodoroSquare(level: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func sessionCount(_ count: Int) -> String {
        switch count {
        case 0: "No sessions"
        case 1: "1 session"
        default: "\(count) sessions"
        }
    }

    // MARK: Year

    private func year(_ shown: [PomodoroHistory.Entry]) -> some View {
        let year = PomodoroHistory.year(shown, now: .now, calendar: .current)
        let cell: CGFloat = 12
        let gap: CGFloat = 3
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: gap) {
                    Color.clear.frame(height: 16)
                    ForEach(0..<7, id: \.self) { row in
                        Text(row == 0 ? "Mon" : (row == 2 ? "Wed" : (row == 4 ? "Fri" : "")))
                            .frame(height: cell)
                    }
                }
                .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(SchemaTheme.inkMuted)
                .fixedSize()

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: gap) {
                        ZStack(alignment: .topLeading) {
                            ForEach(year.months, id: \.column) { month in
                                Text(month.name)
                                    .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                                    .foregroundStyle(SchemaTheme.inkMuted)
                                    .fixedSize()
                                    .offset(x: CGFloat(month.column) * (cell + gap))
                            }
                        }
                        .frame(height: 16, alignment: .topLeading)
                        HStack(alignment: .top, spacing: gap) {
                            ForEach(Array(year.weeks.enumerated()), id: \.offset) { _, days in
                                VStack(spacing: gap) {
                                    ForEach(0..<7, id: \.self) { row in
                                        if let day = days[row] {
                                            PomodoroSquare(level: day.level, size: cell, radius: 3)
                                                .help("\(day.day.formatted(date: .abbreviated, time: .omitted)): \(day.minutes == 0 ? "no focus" : PomodoroHistory.duration(day.minutes))")
                                        } else {
                                            Color.clear.frame(width: cell, height: cell)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(PomodoroHistory.duration(year.totalMinutes)) of focus in the last year")

            HStack(spacing: 12) {
                Text("\(hours(year.totalMinutes)) in the last year. One square is one day.")
                    .font(.satoshi(12, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.inkMuted)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text("Less")
                    ForEach(0..<5, id: \.self) { PomodoroSquare(level: $0, size: 12, radius: 3) }
                    Text("More")
                }
                .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                .foregroundStyle(SchemaTheme.inkMuted)
                .fixedSize()
                .accessibilityHidden(true)
            }
        }
    }

    private func hours(_ minutes: Int) -> String {
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }
}

/// The session running now: outlined, filling from the bottom as it goes.
private struct RunningSquare: View {
    let timer: PomodoroTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let progress = PomodoroEngine.progress(timer, at: context.date)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(SchemaTheme.surfaceSunken)
                Rectangle()
                    .fill(PomodoroShade.fill(level: PomodoroHistory.level(forSessionMinutes: timer.focusMinutes)))
                    .frame(height: 18 * progress)
            }
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(SchemaTheme.lineStrong, lineWidth: 1.5))
            .help("\(timer.name) · running, \(Int(Double(timer.focusMinutes) * progress)) of \(timer.focusMinutes) min")
        }
    }
}

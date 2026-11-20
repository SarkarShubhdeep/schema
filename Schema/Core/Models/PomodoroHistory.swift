//
//  PomodoroHistory.swift
//  Schema
//
//  Finished focus sessions arranged for the heat map (#89). Week: one row
//  per day, today first, one square per session, darker for longer ones.
//  Year: GitHub-style, one square per day in Monday-first week columns,
//  darker for more focus time. Plain values, so they are easy to test.
//

import Foundation

enum PomodoroHistory {
    /// One finished session, as the heat map needs it.
    struct Entry: Equatable {
        var timerID: UUID
        var timerName: String
        var startedAt: Date
        var minutes: Int
    }

    struct DayRow: Identifiable, Equatable {
        var id: Date { day }
        var day: Date
        var isToday: Bool
        var sessions: [Entry]
        var totalMinutes: Int { sessions.reduce(0) { $0 + $1.minutes } }
    }

    struct YearDay: Equatable {
        var day: Date
        var minutes: Int
        var level: Int { PomodoroHistory.level(forDayMinutes: minutes) }
    }

    struct Year: Equatable {
        /// 53 week columns, Monday first; nil for days after today.
        var weeks: [[YearDay?]]
        /// Short month names over the week column where each month starts.
        var months: [(column: Int, name: String)]
        var totalMinutes: Int

        static func == (lhs: Year, rhs: Year) -> Bool {
            lhs.weeks == rhs.weeks && lhs.totalMinutes == rhs.totalMinutes
                && lhs.months.map(\.column) == rhs.months.map(\.column) && lhs.months.map(\.name) == rhs.months.map(\.name)
        }
    }

    /// Shade of one session's square, 1…4: under 25 minutes lightest, 50 or more darkest.
    static func level(forSessionMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<25: 1
        case ..<40: 2
        case ..<50: 3
        default: 4
        }
    }

    /// Shade of one day in the year view, 0…4.
    static func level(forDayMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<1: 0
        case ..<60: 1
        case ..<150: 2
        case ..<240: 3
        default: 4
        }
    }

    /// The last seven days, today first, each with its sessions oldest first.
    static func week(_ entries: [Entry], now: Date, calendar: Calendar) -> [DayRow] {
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.startedAt) }
        return (0..<7).compactMap { offset -> DayRow? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let sessions = (byDay[day] ?? []).sorted { $0.startedAt < $1.startedAt }
            return DayRow(day: day, isToday: offset == 0, sessions: sessions)
        }
    }

    /// 53 weeks ending with this one.
    static func year(_ entries: [Entry], now: Date, calendar: Calendar) -> Year {
        let today = calendar.startOfDay(for: now)
        let weekdayIndex = (calendar.component(.weekday, from: today) + 5) % 7 // Monday = 0
        guard let thisMonday = calendar.date(byAdding: .day, value: -weekdayIndex, to: today),
              let firstMonday = calendar.date(byAdding: .weekOfYear, value: -52, to: thisMonday) else {
            return Year(weeks: [], months: [], totalMinutes: 0)
        }
        var minutesByDay: [Date: Int] = [:]
        for entry in entries {
            minutesByDay[calendar.startOfDay(for: entry.startedAt), default: 0] += entry.minutes
        }
        var weeks: [[YearDay?]] = []
        var months: [(column: Int, name: String)] = []
        var total = 0
        var lastMonth = -1
        let names = calendar.shortMonthSymbols
        for column in 0..<53 {
            guard let monday = calendar.date(byAdding: .day, value: column * 7, to: firstMonday) else { continue }
            var days: [YearDay?] = []
            for row in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: row, to: monday), day <= today else {
                    days.append(nil)
                    continue
                }
                let minutes = minutesByDay[day] ?? 0
                total += minutes
                days.append(YearDay(day: day, minutes: minutes))
            }
            weeks.append(days)
            let month = calendar.component(.month, from: monday)
            if month != lastMonth {
                // The first column is often a partial month; label it only if the next label is far enough away.
                if column > 0 || calendar.component(.day, from: monday) <= 7 {
                    months.append((column, names[month - 1]))
                }
                lastMonth = month
            }
        }
        return Year(weeks: weeks, months: months, totalMinutes: total)
    }

    /// "3h 50m", "45m", "2h".
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}

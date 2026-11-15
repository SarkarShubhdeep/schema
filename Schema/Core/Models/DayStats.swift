//
//  DayStats.swift
//  Schema
//
//  Numbers for the Today dashboard and the overview panel, computed from
//  the tasks in memory: done today, due today, the week's completions by
//  day, upcoming reminders and routine progress.
//

import Foundation

struct DayStats {
    struct WeekDay: Identifiable {
        let date: Date
        let letter: String
        let count: Int
        let isToday: Bool
        let isFuture: Bool
        var id: Date { date }
    }

    struct Reminder: Identifiable {
        let id: UUID
        let title: String
        let pageTitle: String?
        let date: Date
    }

    struct RoutineProgress: Identifiable {
        let id: UUID
        let title: String
        let done: Int
        let total: Int
    }

    let doneToday: Int
    /// Open tasks in Today (due today, overdue, routines that run today).
    let dueToday: Int
    let nextDueTime: Date?
    let week: [WeekDay]
    let weekTotal: Int
    let reminders: [Reminder]
    let routines: [RoutineProgress]

    var totalToday: Int { doneToday + dueToday }

    init(tasks: [SchemaTask], pages: [SchemaList], now: Date = .now, calendar: Calendar = .schema(), reminderLimit: Int = 4) {
        doneToday = tasks.count { $0.wasCompleted(onSameDayAs: now, calendar: calendar) }

        let openToday = tasks.filter { !$0.isCompleted && TaskSection.section(for: $0, now: now, calendar: calendar) == .today }
        dueToday = openToday.count
        nextDueTime = openToday.compactMap(\.reminderTime).filter { $0 > now }.min()

        // Completions per day of the current calendar week.
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekStart = weekInterval?.start ?? calendar.startOfDay(for: now)
        let startOfToday = calendar.startOfDay(for: now)
        let completionDays = tasks.compactMap { $0.completedAt.map { calendar.startOfDay(for: $0) } }
        let countsByDay = Dictionary(completionDays.map { ($0, 1) }, uniquingKeysWith: +)
        week = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return WeekDay(
                date: day,
                letter: String(day.formatted(.dateTime.weekday(.narrow))),
                count: countsByDay[day] ?? 0,
                isToday: day == startOfToday,
                isFuture: day > startOfToday
            )
        }
        weekTotal = week.reduce(0) { $0 + $1.count }

        reminders = tasks
            .filter { !$0.isCompleted && ($0.reminderTime ?? .distantPast) > now }
            .sorted { ($0.reminderTime ?? .distantFuture) < ($1.reminderTime ?? .distantFuture) }
            .prefix(reminderLimit)
            .map { Reminder(id: $0.id, title: $0.title, pageTitle: $0.list?.title, date: $0.reminderTime ?? now) }

        // Routines that run today, per page.
        let weekday = calendar.component(.weekday, from: now)
        let routinesToday = tasks.filter { $0.isRoutine && $0.effectiveRoutineDays.contains(weekday) }
        let byPage = Dictionary(grouping: routinesToday) { $0.list?.id }
        routines = pages.compactMap { page in
            guard let pageRoutines = byPage[page.id], !pageRoutines.isEmpty else { return nil }
            return RoutineProgress(
                id: page.id,
                title: page.title,
                done: pageRoutines.count(where: \.isCompleted),
                total: pageRoutines.count
            )
        }
    }
}

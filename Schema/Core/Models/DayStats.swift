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

    /// One pass over the tasks, reading each property once: this runs on
    /// every redraw of the Today view and the overview panel, and reading a
    /// SwiftData property is slow next to the arithmetic here (#45).
    init(tasks: [SchemaTask], pages: [SchemaList], now: Date = .now, calendar: Calendar = .schema(), reminderLimit: Int = 4) {
        let clock = TaskSectionClock(now: now, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

        var doneToday = 0
        var dueToday = 0
        var nextDueTime: Date?
        var countsByDay: [Date: Int] = [:]
        var upcoming: [(task: SchemaTask, date: Date)] = []
        var routineCounts: [UUID: (done: Int, total: Int)] = [:]

        for task in tasks {
            if let completedAt = task.completedAt {
                if completedAt >= startOfToday, completedAt < clock.startOfTomorrow { doneToday += 1 }
                if completedAt >= weekStart, completedAt < weekEnd {
                    countsByDay[calendar.startOfDay(for: completedAt), default: 0] += 1
                }
            }
            let isCompleted = task.isCompleted
            let reminder = task.reminderTime
            // As TaskSection: a routine with no time is due on the days it runs.
            let runsToday = task.isRoutine && task.effectiveRoutineDays.contains(clock.weekday)
            if !isCompleted {
                let isDueToday = reminder.map { $0 < clock.startOfTomorrow } ?? runsToday
                if isDueToday {
                    dueToday += 1
                    if let reminder, reminder > now, reminder < (nextDueTime ?? .distantFuture) {
                        nextDueTime = reminder
                    }
                }
                if let reminder, reminder > now {
                    upcoming.append((task, reminder))
                }
            }
            if runsToday, let listID = task.list?.id {
                var counts = routineCounts[listID] ?? (0, 0)
                counts.total += 1
                if isCompleted { counts.done += 1 }
                routineCounts[listID] = counts
            }
        }

        self.doneToday = doneToday
        self.dueToday = dueToday
        self.nextDueTime = nextDueTime

        // Completions per day of the current calendar week.
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

        reminders = upcoming
            .sorted { $0.date < $1.date }
            .prefix(reminderLimit)
            .map { Reminder(id: $0.task.id, title: $0.task.title, pageTitle: $0.task.list?.title, date: $0.date) }

        // Routines that run today, per page.
        routines = pages.compactMap { page in
            guard let counts = routineCounts[page.id], counts.total > 0 else { return nil }
            return RoutineProgress(id: page.id, title: page.title, done: counts.done, total: counts.total)
        }
    }
}

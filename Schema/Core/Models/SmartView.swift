//
//  SmartView.swift
//  Schema
//
//  Views in the sidebar that gather tasks from every page by date.
//  For now they are filtered task lists; the Today dashboard and Upcoming
//  by day arrive with #17.
//

import Foundation

enum SmartView: String, CaseIterable, Identifiable {
    case today
    case upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .upcoming: "Upcoming"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .upcoming: "calendar"
        }
    }

    /// Today: open tasks due today, overdue, or routines that run today;
    /// plus tasks completed today.
    /// Upcoming: open tasks due after today.
    func includes(_ task: SchemaTask, now: Date = .now, calendar: Calendar = .schema()) -> Bool {
        includes(task, clock: TaskSectionClock(now: now, calendar: calendar), calendar: calendar)
    }

    /// Same, with the day boundaries worked out once for many tasks.
    func includes(_ task: SchemaTask, clock: TaskSectionClock, calendar: Calendar = .schema()) -> Bool {
        switch self {
        case .today:
            if task.isCompleted {
                return task.wasCompleted(onSameDayAs: clock.now, calendar: calendar)
            }
            return clock.section(for: task) == .today
        case .upcoming:
            guard !task.isCompleted, let reminder = task.reminderTime else { return false }
            return reminder >= clock.startOfTomorrow
        }
    }
}

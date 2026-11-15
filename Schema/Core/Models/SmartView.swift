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

    /// Today: open tasks due today or overdue, and tasks done that were due today.
    /// Upcoming: tasks due after today.
    func includes(_ task: SchemaTask, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let reminder = task.reminderTime else { return false }
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return false }

        switch self {
        case .today:
            if task.isCompleted {
                return reminder >= startOfToday && reminder < startOfTomorrow
            }
            return reminder < startOfTomorrow
        case .upcoming:
            return reminder >= startOfTomorrow
        }
    }
}

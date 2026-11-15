//
//  TaskSection.swift
//  Schema
//
//  Groups a page's open tasks by when they are due: Today (due today,
//  overdue, or a routine that runs today), Later this week, Later, and
//  Someday (no date). Routine chain followers stay with their chain's first
//  task so a chain is never split across sections.
//

import Foundation

enum TaskSection: Int, CaseIterable, Identifiable {
    case today
    case thisWeek
    case later
    case someday

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .thisWeek: "Later this week"
        case .later: "Later"
        case .someday: "Someday"
        }
    }

    var hint: String {
        switch self {
        case .today: "Due or planned for today"
        case .thisWeek, .later: ""
        case .someday: "No date"
        }
    }

    static func section(for task: SchemaTask, now: Date = .now, calendar: Calendar = .current) -> TaskSection {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let startOfNextWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? startOfTomorrow

        guard let reminder = task.reminderTime else {
            if task.isRoutine, task.effectiveRoutineDays.contains(calendar.component(.weekday, from: now)) {
                return .today
            }
            return .someday
        }
        if reminder < startOfTomorrow { return .today }
        if reminder < startOfNextWeek { return .thisWeek }
        return .later
    }

    /// Non-empty sections in display order. Tasks keep their incoming order
    /// within a section.
    static func group(_ tasks: [SchemaTask], now: Date = .now, calendar: Calendar = .current) -> [TaskSectionGroup] {
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var sectionByID: [UUID: TaskSection] = [:]

        func resolve(_ task: SchemaTask, depth: Int = 0) -> TaskSection {
            if let known = sectionByID[task.id] { return known }
            let section: TaskSection
            if depth < 64, let previousID = task.afterTaskID, let previous = byID[previousID] {
                section = resolve(previous, depth: depth + 1)
            } else {
                section = Self.section(for: task, now: now, calendar: calendar)
            }
            sectionByID[task.id] = section
            return section
        }

        var buckets: [TaskSection: [SchemaTask]] = [:]
        for task in tasks {
            buckets[resolve(task), default: []].append(task)
        }
        return allCases.compactMap { section in
            guard let tasks = buckets[section], !tasks.isEmpty else { return nil }
            return TaskSectionGroup(section: section, tasks: tasks)
        }
    }
}

struct TaskSectionGroup: Identifiable {
    let section: TaskSection
    let tasks: [SchemaTask]
    var id: Int { section.id }
}

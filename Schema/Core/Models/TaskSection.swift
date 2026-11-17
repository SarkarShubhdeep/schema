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

    static func section(for task: SchemaTask, now: Date = .now, calendar: Calendar = .schema()) -> TaskSection {
        TaskSectionClock(now: now, calendar: calendar).section(for: task)
    }

    /// Non-empty sections in display order. Tasks keep their incoming order
    /// within a section.
    static func group(_ tasks: [SchemaTask], now: Date = .now, calendar: Calendar = .schema()) -> [TaskSectionGroup] {
        let clock = TaskSectionClock(now: now, calendar: calendar)
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var sectionByID: [UUID: TaskSection] = [:]

        func resolve(_ task: SchemaTask, depth: Int = 0) -> TaskSection {
            if let known = sectionByID[task.id] { return known }
            let section: TaskSection
            if depth < 64, let previousID = task.afterTaskID, let previous = byID[previousID] {
                section = resolve(previous, depth: depth + 1)
            } else {
                section = clock.section(for: task)
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
            return TaskSectionGroup(id: "section-\(section.rawValue)", title: section.title, hint: section.hint, tasks: tasks)
        }
    }

    /// Today view: one group per page, in sidebar order.
    static func groupByPage(_ tasks: [SchemaTask], pages: [SchemaList]) -> [TaskSectionGroup] {
        let byList = Dictionary(grouping: tasks) { $0.list?.id }
        var groups = pages.compactMap { page -> TaskSectionGroup? in
            guard let tasks = byList[page.id], !tasks.isEmpty else { return nil }
            return TaskSectionGroup(id: "page-\(page.id)", title: page.title, hint: "", tasks: tasks)
        }
        let known = Set(pages.map(\.id))
        let other = tasks.filter { task in task.list.map { !known.contains($0.id) } ?? true }
        if !other.isEmpty {
            groups.append(TaskSectionGroup(id: "page-other", title: "Other", hint: "", tasks: other))
        }
        return groups
    }

    /// Upcoming view: one group per day, earliest first.
    static func groupByDay(_ tasks: [SchemaTask], now: Date = .now, calendar: Calendar = .current) -> [TaskSectionGroup] {
        let dated = tasks.filter { $0.reminderTime != nil }
            .sorted { ($0.reminderTime ?? .distantFuture) < ($1.reminderTime ?? .distantFuture) }
        let byDay = Dictionary(grouping: dated) { calendar.startOfDay(for: $0.reminderTime ?? now) }
        return byDay.keys.sorted().map { day in
            TaskSectionGroup(
                id: "day-\(Int(day.timeIntervalSinceReferenceDate))",
                title: DayLabel.title(for: day, now: now, calendar: calendar),
                hint: calendar.isDateInTomorrow(day) ? "" : day.formatted(.dateTime.month(.abbreviated).day()),
                tasks: byDay[day] ?? []
            )
        }
    }
}

/// The day boundaries `TaskSection` needs, worked out once for a whole list
/// rather than per task (#45).
struct TaskSectionClock {
    let now: Date
    let startOfTomorrow: Date
    let startOfNextWeek: Date
    let weekday: Int

    init(now: Date = .now, calendar: Calendar = .schema()) {
        self.now = now
        let startOfToday = calendar.startOfDay(for: now)
        startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        startOfNextWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? startOfTomorrow
        weekday = calendar.component(.weekday, from: now)
    }

    func section(for task: SchemaTask) -> TaskSection {
        guard let reminder = task.reminderTime else {
            if task.isRoutine, task.effectiveRoutineDays.contains(weekday) {
                return .today
            }
            return .someday
        }
        if reminder < startOfTomorrow { return .today }
        if reminder < startOfNextWeek { return .thisWeek }
        return .later
    }
}

/// A titled group of tasks shown as one card.
struct TaskSectionGroup: Identifiable {
    let id: String
    let title: String
    let hint: String
    let tasks: [SchemaTask]
}

enum DayLabel {
    /// "Today", "Tomorrow", a weekday within the next week, else "Mon, Nov 30".
    static func title(for day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        let startOfToday = calendar.startOfDay(for: now)
        if let days = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: day)).day, days < 7 {
            return day.formatted(.dateTime.weekday(.wide))
        }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

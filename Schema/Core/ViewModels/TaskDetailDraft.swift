//
//  TaskDetailDraft.swift
//  Schema
//
//  Editable copy of a task's schedule (due date and time, routine days,
//  the routine it follows). The task page's Properties card edits it and
//  saves it through TaskViewModel.applyDetailChanges.
//

import Foundation
import Observation

struct WeekdayInfo {
    let weekday: Int
    let shortLabel: String
    let fullName: String

    static let ordered: [WeekdayInfo] = [
        WeekdayInfo(weekday: 2, shortLabel: "M", fullName: "Monday"),
        WeekdayInfo(weekday: 3, shortLabel: "T", fullName: "Tuesday"),
        WeekdayInfo(weekday: 4, shortLabel: "W", fullName: "Wednesday"),
        WeekdayInfo(weekday: 5, shortLabel: "T", fullName: "Thursday"),
        WeekdayInfo(weekday: 6, shortLabel: "F", fullName: "Friday"),
        WeekdayInfo(weekday: 7, shortLabel: "S", fullName: "Saturday"),
        WeekdayInfo(weekday: 1, shortLabel: "S", fullName: "Sunday"),
    ]

    static var allWeekdays: Set<Int> {
        Set(ordered.map(\.weekday))
    }
}

struct TaskDetailDraft {
    var title: String
    var description: String
    var selectedTime: Date?
    var selectedDate: Date?
    var isRoutine: Bool
    var routineDays: Set<Int>
    var afterTaskID: UUID?

    var hasReminder: Bool {
        selectedTime != nil
    }

    var computedReminderDate: Date? {
        guard let time = selectedTime else { return nil }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        if isRoutine {
            return time
        }

        if let date = selectedDate {
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            return calendar.date(from: dateComponents)
        } else {
            return Self.nextOccurrence(hour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0)
        }
    }

    init(task: SchemaTask) {
        title = task.title
        description = task.taskDescription ?? ""
        isRoutine = task.isRoutine
        afterTaskID = task.afterTaskID

        if task.isRoutine {
            routineDays = task.routineDays.isEmpty
                ? WeekdayInfo.allWeekdays
                : Set(task.routineDays)
        } else {
            routineDays = Set(task.routineDays)
        }

        if let reminder = task.reminderTime {
            selectedTime = reminder
            selectedDate = isRoutine ? nil : reminder
        } else {
            selectedTime = nil
            selectedDate = nil
        }
    }

    var normalizedRoutineDays: [Int] {
        Array(routineDays).sorted()
    }

    mutating func enableRoutine() {
        isRoutine = true
        if routineDays.isEmpty {
            routineDays = WeekdayInfo.allWeekdays
        }
    }

    mutating func disableRoutine() {
        isRoutine = false
        afterTaskID = nil
    }

    mutating func clearReminder() {
        selectedTime = nil
        selectedDate = nil
    }

    func isDaySelected(_ weekday: Int) -> Bool {
        routineDays.contains(weekday)
    }

    mutating func toggleDay(_ weekday: Int) {
        if routineDays.contains(weekday) {
            routineDays.remove(weekday)
        } else {
            routineDays.insert(weekday)
        }
    }

    static func nextOccurrence(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let todayAtTime = calendar.date(from: components) else {
            return now
        }

        if todayAtTime > now {
            return todayAtTime
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayAtTime) ?? todayAtTime
        }
    }
}

@Observable
@MainActor
final class TaskDetailEditor {
    let taskID: UUID
    var draft: TaskDetailDraft
    var selectedListCandidateIndex = 0

    init(task: SchemaTask) {
        taskID = task.id
        draft = TaskDetailDraft(task: task)
    }
}

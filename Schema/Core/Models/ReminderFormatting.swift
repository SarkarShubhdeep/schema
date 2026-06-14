//
//  ReminderFormatting.swift
//  Schema
//

import Foundation

enum ReminderFormatting {
    static func displayString(for date: Date, relativeTo now: Date = .now) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)

        if calendar.isDateInToday(date) {
            return time
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday \(time)"
        }

        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(time)"
        }

        let dateYear = calendar.component(.year, from: date)
        let nowYear = calendar.component(.year, from: now)
        let datePart = dateYear == nowYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())

        return "\(datePart), \(time)"
    }
}

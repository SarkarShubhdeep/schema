//
//  ReminderFormatting.swift
//  Schema
//

import Foundation

enum ReminderFormatting {
    static func displayString(for date: Date, relativeTo now: Date = .now) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        if calendar.isDateInTomorrow(date) {
            let time = date.formatted(date: .omitted, time: .shortened)
            return "Tomorrow \(time)"
        }

        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day,
           days > 1, days <= 7 {
            let weekday = date.formatted(.dateTime.weekday(.wide))
            let time = date.formatted(date: .omitted, time: .shortened)
            return "\(weekday) \(time)"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

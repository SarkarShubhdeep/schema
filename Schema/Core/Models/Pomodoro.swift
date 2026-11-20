//
//  Pomodoro.swift
//  Schema
//
//  Pomodoro timers and the focus sessions they finish (#89, schema V8).
//  A timer alternates focus and break. While it runs it stores when the
//  current phase ends; while paused, how much of it is left. A session is
//  saved each time a focus phase finishes, with the timer's name copied in,
//  so history stays readable after the timer is removed.
//

import Foundation
import SwiftData

enum PomodoroPhase: String, Codable, Sendable {
    case focus
    case rest = "break"
}

@Model
final class PomodoroTimer {
    var id: UUID = UUID()
    var name: String = ""
    var focusMinutes: Int = 25
    /// 0 means no break: the next focus starts right after.
    var breakMinutes: Int = 5
    /// Breaks and the next focus start by themselves; otherwise each waits for Resume.
    var startsPhasesAutomatically: Bool = true
    var createdAt: Date = Date.now
    var sortIndex: Double = 0
    /// The page or task the time counts toward, if any.
    var linkedPageID: UUID?
    var linkedTaskID: UUID?

    var phaseRaw: String = PomodoroPhase.focus.rawValue
    /// When the current phase ends. Nil while paused.
    var phaseEndsAt: Date?
    /// Seconds left in the current phase while paused.
    var pausedRemaining: Double = 0
    /// When the focus phase now running (or paused) began, for the session record.
    var focusStartedAt: Date?

    init(name: String, focusMinutes: Int, breakMinutes: Int, startsPhasesAutomatically: Bool = true, sortIndex: Double = 0) {
        self.id = UUID()
        self.name = name
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.startsPhasesAutomatically = startsPhasesAutomatically
        self.createdAt = .now
        self.sortIndex = sortIndex
    }

    var phase: PomodoroPhase {
        get { PomodoroPhase(rawValue: phaseRaw) ?? .focus }
        set { phaseRaw = newValue.rawValue }
    }

    var isRunning: Bool { phaseEndsAt != nil }
}

@Model
final class PomodoroSession {
    var id: UUID = UUID()
    var timerID: UUID = UUID()
    /// The timer's name when the session finished.
    var timerName: String = ""
    var startedAt: Date = Date.now
    var endedAt: Date = Date.now
    /// Focus minutes in this session: the timer's length, or less when finished early.
    var minutes: Int = 25

    init(timerID: UUID, timerName: String, startedAt: Date, endedAt: Date, minutes: Int) {
        self.id = UUID()
        self.timerID = timerID
        self.timerName = timerName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.minutes = minutes
    }
}

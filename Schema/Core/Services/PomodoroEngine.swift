//
//  PomodoroEngine.swift
//  Schema
//
//  The rules of a Pomodoro timer (#89), as plain functions on its stored
//  state so they are easy to test. Time is never counted with a ticking
//  number: a running phase stores when it ends, so the timer keeps time
//  while the page, the window or the whole app is closed.
//
//  When the app was not running as a phase ended (it ended more than
//  `lateTolerance` ago), the timer still finishes that phase and saves the
//  session, but waits for Resume instead of starting the next one, so a
//  timer left on overnight does not fill the night with sessions.
//

import Foundation

enum PomodoroEngine {
    /// A focus phase that finished, to be saved as a session.
    struct FinishedFocus: Equatable {
        var startedAt: Date
        var endedAt: Date
        var minutes: Int
    }

    /// How late a phase end can be noticed and still count as "the app was there".
    static let lateTolerance: TimeInterval = 90

    static func length(of phase: PomodoroPhase, for timer: PomodoroTimer) -> TimeInterval {
        TimeInterval(phase == .focus ? timer.focusMinutes : timer.breakMinutes) * 60
    }

    /// Seconds left in the current phase.
    static func remaining(_ timer: PomodoroTimer, at now: Date) -> TimeInterval {
        if let end = timer.phaseEndsAt { return max(0, end.timeIntervalSince(now)) }
        return max(0, timer.pausedRemaining)
    }

    /// How far through the current phase, 0…1.
    static func progress(_ timer: PomodoroTimer, at now: Date) -> Double {
        let total = length(of: timer.phase, for: timer)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(timer, at: now) / total))
    }

    /// Paused at the very start of a phase: waiting to be started.
    static func isWaiting(_ timer: PomodoroTimer) -> Bool {
        !timer.isRunning && timer.pausedRemaining >= length(of: timer.phase, for: timer) - 0.5
    }

    /// A new focus phase, running from `now`.
    static func start(_ timer: PomodoroTimer, at now: Date) {
        enter(.focus, for: timer, at: now, running: true)
    }

    /// Moves the timer past every phase end up to `now`. Returns the focus
    /// phases that finished on the way, oldest first.
    @discardableResult
    static func advance(_ timer: PomodoroTimer, to now: Date) -> [FinishedFocus] {
        var finished: [FinishedFocus] = []
        var steps = 0
        while let end = timer.phaseEndsAt, end <= now, steps < 500 {
            steps += 1
            let wasThere = now.timeIntervalSince(end) <= lateTolerance
            let runsOn = timer.startsPhasesAutomatically && wasThere
            switch timer.phase {
            case .focus:
                let length = length(of: .focus, for: timer)
                finished.append(FinishedFocus(
                    startedAt: timer.focusStartedAt ?? end.addingTimeInterval(-length),
                    endedAt: end,
                    minutes: timer.focusMinutes
                ))
                enter(timer.breakMinutes > 0 ? .rest : .focus, for: timer, at: end, running: runsOn)
            case .rest:
                enter(.focus, for: timer, at: end, running: runsOn)
            }
        }
        return finished
    }

    static func pause(_ timer: PomodoroTimer, at now: Date) {
        guard let end = timer.phaseEndsAt else { return }
        timer.pausedRemaining = max(0, end.timeIntervalSince(now))
        timer.phaseEndsAt = nil
    }

    static func resume(_ timer: PomodoroTimer, at now: Date) {
        guard !timer.isRunning else { return }
        if timer.phase == .focus, timer.focusStartedAt == nil {
            let elapsed = length(of: .focus, for: timer) - timer.pausedRemaining
            timer.focusStartedAt = now.addingTimeInterval(-max(0, elapsed))
        }
        timer.phaseEndsAt = now.addingTimeInterval(timer.pausedRemaining)
        timer.pausedRemaining = 0
    }

    /// Ends the break now and starts focusing.
    static func skipBreak(_ timer: PomodoroTimer, at now: Date) {
        guard timer.phase == .rest else { return }
        enter(.focus, for: timer, at: now, running: true)
    }

    /// Ends the focus phase now. It counts as a session of the minutes
    /// actually spent, if at least one; then the break follows as usual.
    @discardableResult
    static func finishFocus(_ timer: PomodoroTimer, at now: Date) -> FinishedFocus? {
        guard timer.phase == .focus else { return nil }
        let spent = length(of: .focus, for: timer) - remaining(timer, at: now)
        let minutes = Int((spent / 60).rounded())
        let started = timer.focusStartedAt ?? now.addingTimeInterval(-spent)
        enter(timer.breakMinutes > 0 ? .rest : .focus, for: timer, at: now, running: timer.startsPhasesAutomatically)
        guard minutes >= 1 else { return nil }
        return FinishedFocus(startedAt: started, endedAt: now, minutes: minutes)
    }

    /// Starts a full focus phase now, dropping the one in progress (nothing is saved).
    static func restartFocus(_ timer: PomodoroTimer, at now: Date) {
        enter(.focus, for: timer, at: now, running: true)
    }

    private static func enter(_ phase: PomodoroPhase, for timer: PomodoroTimer, at start: Date, running: Bool) {
        timer.phase = phase
        let length = length(of: phase, for: timer)
        if phase == .focus { timer.focusStartedAt = running ? start : nil }
        if running {
            timer.phaseEndsAt = start.addingTimeInterval(length)
            timer.pausedRemaining = 0
        } else {
            timer.phaseEndsAt = nil
            timer.pausedRemaining = length
        }
    }
}

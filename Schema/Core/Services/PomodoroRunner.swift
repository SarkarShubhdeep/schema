//
//  PomodoroRunner.swift
//  Schema
//
//  Keeps Pomodoro timers moving while the app runs (#89): once a second it
//  moves running timers past any phase end, saves the finished focus
//  sessions, and keeps one notification scheduled per running timer for
//  the end of its current phase. The window does not need to be open.
//  Every action from the page goes through here so the store and the
//  notifications stay in step.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
protocol PomodoroNotifying: AnyObject {
    func schedule(for timer: PomodoroTimer, at now: Date)
    func cancel(for timerID: UUID)
}

@Observable
@MainActor
final class PomodoroRunner {
    private let context: ModelContext
    private let notifications: (any PomodoroNotifying)?

    init(context: ModelContext, notifications: (any PomodoroNotifying)?) {
        self.context = context
        self.notifications = notifications
    }

    /// With system notifications.
    convenience init(context: ModelContext) {
        self.init(context: context, notifications: PomodoroNotifications())
    }

    /// Ticks until the task is cancelled.
    func run() async {
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Moves every running timer up to `now`.
    func tick(now: Date = .now) {
        let running = FetchDescriptor<PomodoroTimer>(predicate: #Predicate { $0.phaseEndsAt != nil })
        guard let timers = try? context.fetch(running) else { return }
        var changed = false
        for timer in timers {
            guard let end = timer.phaseEndsAt, end <= now else { continue }
            record(PomodoroEngine.advance(timer, to: now), for: timer)
            notifications?.schedule(for: timer, at: now)
            changed = true
        }
        if changed { try? context.save() }
    }

    // MARK: Actions

    @discardableResult
    func start(name: String, focusMinutes: Int, breakMinutes: Int, automatic: Bool, linkedPageID: UUID? = nil, linkedTaskID: UUID? = nil, now: Date = .now) -> PomodoroTimer {
        let existing = (try? context.fetch(FetchDescriptor<PomodoroTimer>())) ?? []
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let timer = PomodoroTimer(
            name: trimmed.isEmpty ? "Focus" : trimmed,
            focusMinutes: max(1, focusMinutes),
            breakMinutes: max(0, breakMinutes),
            startsPhasesAutomatically: automatic,
            sortIndex: (existing.map(\.sortIndex).max() ?? 0) + 1
        )
        timer.linkedPageID = linkedPageID
        timer.linkedTaskID = linkedTaskID
        context.insert(timer)
        PomodoroEngine.start(timer, at: now)
        changed(timer, at: now)
        return timer
    }

    func togglePause(_ timer: PomodoroTimer, now: Date = .now) {
        if timer.isRunning {
            record(PomodoroEngine.advance(timer, to: now), for: timer)
            PomodoroEngine.pause(timer, at: now)
        } else {
            PomodoroEngine.resume(timer, at: now)
        }
        changed(timer, at: now)
    }

    func skipBreak(_ timer: PomodoroTimer, now: Date = .now) {
        PomodoroEngine.skipBreak(timer, at: now)
        changed(timer, at: now)
    }

    func finishFocus(_ timer: PomodoroTimer, now: Date = .now) {
        record(PomodoroEngine.finishFocus(timer, at: now).map { [$0] } ?? [], for: timer)
        changed(timer, at: now)
    }

    func restartFocus(_ timer: PomodoroTimer, now: Date = .now) {
        PomodoroEngine.restartFocus(timer, at: now)
        changed(timer, at: now)
    }

    func rename(_ timer: PomodoroTimer, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        timer.name = trimmed
        changed(timer, at: .now)
    }

    /// New lengths apply from the next phase; a waiting phase takes the new length now.
    func setLengths(_ timer: PomodoroTimer, focus: Int? = nil, rest: Int? = nil) {
        let wasWaiting = PomodoroEngine.isWaiting(timer)
        if let focus { timer.focusMinutes = max(1, focus) }
        if let rest { timer.breakMinutes = max(0, rest) }
        if wasWaiting { timer.pausedRemaining = PomodoroEngine.length(of: timer.phase, for: timer) }
        changed(timer, at: .now)
    }

    func setAutomatic(_ timer: PomodoroTimer, _ automatic: Bool) {
        timer.startsPhasesAutomatically = automatic
        changed(timer, at: .now)
    }

    /// Stops the timer and removes it. Its finished sessions stay in the history.
    func remove(_ timer: PomodoroTimer) {
        notifications?.cancel(for: timer.id)
        context.delete(timer)
        try? context.save()
    }

    // MARK: Saving

    private func record(_ finished: [PomodoroEngine.FinishedFocus], for timer: PomodoroTimer) {
        for focus in finished {
            context.insert(PomodoroSession(
                timerID: timer.id,
                timerName: timer.name,
                startedAt: focus.startedAt,
                endedAt: focus.endedAt,
                minutes: focus.minutes
            ))
        }
    }

    private func changed(_ timer: PomodoroTimer, at now: Date) {
        try? context.save()
        notifications?.schedule(for: timer, at: now)
    }
}

/// One local notification per running timer, for the end of its current phase.
@MainActor
final class PomodoroNotifications: PomodoroNotifying {
    private var askedForPermission = false

    func schedule(for timer: PomodoroTimer, at now: Date) {
        #if DEBUG
        if DemoData.isEnabled { return }
        #endif
        let center = UNUserNotificationCenter.current()
        let id = Self.identifier(timer.id)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let end = timer.phaseEndsAt else { return }
        if !askedForPermission {
            askedForPermission = true
            Task { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
        }
        let content = UNMutableNotificationContent()
        let text = Self.text(for: timer)
        content.title = text.title
        content.body = text.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSince(now)), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(for timerID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(timerID)])
    }

    static func identifier(_ timerID: UUID) -> String { "pomodoro-\(timerID.uuidString)" }

    /// What the notification at the end of the current phase says.
    static func text(for timer: PomodoroTimer) -> (title: String, body: String) {
        let automatic = timer.startsPhasesAutomatically
        switch timer.phase {
        case .focus:
            let body: String
            if timer.breakMinutes > 0 {
                body = automatic ? "Your \(timer.breakMinutes) min break has started." : "Start your \(timer.breakMinutes) min break when you're ready."
            } else {
                body = automatic ? "The next session has started." : "Start the next session when you're ready."
            }
            return ("Focus done: \(timer.name)", body)
        case .rest:
            return ("Break over: \(timer.name)", automatic ? "Back to focus for \(timer.focusMinutes) min." : "Start the next session when you're ready.")
        }
    }
}

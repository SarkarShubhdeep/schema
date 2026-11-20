//
//  PomodoroTests.swift
//  SchemaTests
//
//  Pomodoro timers (#89): phases, pausing, skipping, finishing early,
//  catching up after the app was closed, and the heat map's days.
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct PomodoroEngineTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func timer(focus: Int = 25, rest: Int = 5, automatic: Bool = true) -> PomodoroTimer {
        let timer = PomodoroTimer(name: "Write", focusMinutes: focus, breakMinutes: rest, startsPhasesAutomatically: automatic)
        PomodoroEngine.start(timer, at: t0)
        return timer
    }

    private func at(minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    @Test func focusEndsIntoABreakAndCountsOneSession() {
        let timer = timer()
        #expect(PomodoroEngine.advance(timer, to: at(minutes: 10)).isEmpty)
        #expect(PomodoroEngine.remaining(timer, at: at(minutes: 10)) == 15 * 60)

        let finished = PomodoroEngine.advance(timer, to: at(minutes: 25.5))
        #expect(finished == [.init(startedAt: t0, endedAt: at(minutes: 25), minutes: 25)])
        #expect(timer.phase == .rest)
        #expect(timer.phaseEndsAt == at(minutes: 30))
    }

    @Test func breakEndsIntoTheNextFocus() {
        let timer = timer()
        PomodoroEngine.advance(timer, to: at(minutes: 25.2))
        PomodoroEngine.advance(timer, to: at(minutes: 30.2))
        #expect(timer.phase == .focus)
        #expect(timer.focusStartedAt == at(minutes: 30))
        #expect(timer.phaseEndsAt == at(minutes: 55))
    }

    @Test func withoutAutomaticStartEachPhaseWaits() {
        let timer = timer(automatic: false)
        PomodoroEngine.advance(timer, to: at(minutes: 25.2))
        #expect(timer.phase == .rest)
        #expect(!timer.isRunning)
        #expect(PomodoroEngine.isWaiting(timer))
        #expect(PomodoroEngine.remaining(timer, at: at(minutes: 40)) == 5 * 60)
    }

    @Test func noBreakGoesStraightToTheNextFocus() {
        let timer = timer(rest: 0)
        let finished = PomodoroEngine.advance(timer, to: at(minutes: 25.2))
        #expect(finished.count == 1)
        #expect(timer.phase == .focus)
        #expect(timer.phaseEndsAt == at(minutes: 50))
    }

    @Test func afterTheAppWasClosedItFinishesThePhaseThenWaits() {
        let timer = timer()
        // Opened again eight hours later: one session counts, then it waits.
        let finished = PomodoroEngine.advance(timer, to: at(minutes: 8 * 60))
        #expect(finished.count == 1)
        #expect(timer.phase == .rest)
        #expect(PomodoroEngine.isWaiting(timer))
    }

    @Test func pauseKeepsTheTimeLeftAndResumeContinues() {
        let timer = timer()
        PomodoroEngine.pause(timer, at: at(minutes: 10))
        #expect(!timer.isRunning)
        #expect(PomodoroEngine.remaining(timer, at: at(minutes: 60)) == 15 * 60)
        PomodoroEngine.resume(timer, at: at(minutes: 60))
        #expect(timer.phaseEndsAt == at(minutes: 75))
        // The session still starts when focus began.
        #expect(PomodoroEngine.advance(timer, to: at(minutes: 75.1)).first?.startedAt == t0)
    }

    @Test func skipBreakStartsFocusNow() {
        let timer = timer()
        PomodoroEngine.advance(timer, to: at(minutes: 26))
        PomodoroEngine.skipBreak(timer, at: at(minutes: 27))
        #expect(timer.phase == .focus)
        #expect(timer.phaseEndsAt == at(minutes: 52))
    }

    @Test func finishingEarlyCountsTheMinutesSpent() {
        let timer = timer(focus: 40)
        let finished = PomodoroEngine.finishFocus(timer, at: at(minutes: 30))
        #expect(finished == .init(startedAt: t0, endedAt: at(minutes: 30), minutes: 30))
        #expect(timer.phase == .rest)
        #expect(timer.phaseEndsAt == at(minutes: 35))
    }

    @Test func finishingInTheFirstSecondsSavesNothing() {
        let timer = timer()
        #expect(PomodoroEngine.finishFocus(timer, at: t0.addingTimeInterval(20)) == nil)
        #expect(timer.phase == .rest)
    }

    @Test func runnerSavesSessionsWhenItTicks() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaCurrentVersion.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let runner = PomodoroRunner(context: container.mainContext, notifications: nil)
        let timer = runner.start(name: "  ", focusMinutes: 25, breakMinutes: 5, automatic: true, now: t0)
        #expect(timer.name == "Focus")
        runner.tick(now: at(minutes: 25.5))
        let sessions = try container.mainContext.fetch(FetchDescriptor<PomodoroSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.timerName == "Focus")
        runner.remove(timer)
        #expect(try container.mainContext.fetch(FetchDescriptor<PomodoroSession>()).count == 1)
    }
}

struct PomodoroHistoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Friday, 20 November 2026, 15:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_795_186_800)
    private let timerID = UUID()

    private func entry(daysAgo: Int, hour: Int, minutes: Int) -> PomodoroHistory.Entry {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        return .init(timerID: timerID, timerName: "Write", startedAt: day.addingTimeInterval(TimeInterval(hour * 3600)), minutes: minutes)
    }

    @Test func sessionShadesGetDarkerWithLength() {
        #expect(PomodoroHistory.level(forSessionMinutes: 10) == 1)
        #expect(PomodoroHistory.level(forSessionMinutes: 25) == 2)
        #expect(PomodoroHistory.level(forSessionMinutes: 45) == 3)
        #expect(PomodoroHistory.level(forSessionMinutes: 50) == 4)
    }

    @Test func weekIsSevenDaysTodayFirstWithSessionsInOrder() {
        let rows = PomodoroHistory.week([
            entry(daysAgo: 0, hour: 11, minutes: 40),
            entry(daysAgo: 0, hour: 9, minutes: 25),
            entry(daysAgo: 2, hour: 10, minutes: 50),
            entry(daysAgo: 9, hour: 10, minutes: 25),
        ], now: now, calendar: calendar)
        #expect(rows.count == 7)
        #expect(rows[0].isToday)
        #expect(rows[0].sessions.map(\.minutes) == [25, 40])
        #expect(rows[0].totalMinutes == 65)
        #expect(rows[2].sessions.count == 1)
        #expect(rows.reduce(0) { $0 + $1.sessions.count } == 3)
    }

    @Test func yearHas53MondayFirstWeeksEndingToday() {
        let year = PomodoroHistory.year([
            entry(daysAgo: 0, hour: 9, minutes: 250),
            entry(daysAgo: 3, hour: 9, minutes: 30),
            entry(daysAgo: 400, hour: 9, minutes: 30),
        ], now: now, calendar: calendar)
        #expect(year.weeks.count == 53)
        let last = year.weeks[52]
        // Friday is the fifth row; Saturday and Sunday are still to come.
        #expect(last[4]?.minutes == 250)
        #expect(last[4]?.level == 4)
        #expect(last[5] == nil && last[6] == nil)
        // Tuesday of this week.
        #expect(last[1]?.minutes == 30)
        #expect(year.totalMinutes == 280)
        #expect(!year.months.isEmpty)
    }

    @Test func durationsReadShort() {
        #expect(PomodoroHistory.duration(45) == "45m")
        #expect(PomodoroHistory.duration(120) == "2h")
        #expect(PomodoroHistory.duration(230) == "3h 50m")
    }
}

//
//  PomodoroPageView.swift
//  Schema
//
//  The Pomodoro page (#89): New timer, a card for each timer (several can
//  run at once), and the focus history heat map. Space pauses or resumes
//  the timer that ends soonest.
//

import SwiftData
import SwiftUI

struct PomodoroPageView: View {
    let pages: [SchemaList]
    let onOpenPage: (SchemaList) -> Void

    @Environment(PomodoroRunner.self) private var runner
    @Query(sort: \PomodoroTimer.sortIndex) private var timers: [PomodoroTimer]
    @Query private var sessions: [PomodoroSession]
    @State private var isAdding = false

    init(pages: [SchemaList], onOpenPage: @escaping (SchemaList) -> Void) {
        self.pages = pages
        self.onOpenPage = onOpenPage
        // A year of history is what the heat map can show.
        let start = Calendar.current.date(byAdding: .day, value: -372, to: .now) ?? .distantPast
        _sessions = Query(filter: #Predicate<PomodoroSession> { $0.startedAt >= start }, sort: \.startedAt)
    }

    var body: some View {
        let entries = sessions.map {
            PomodoroHistory.Entry(timerID: $0.timerID, timerName: $0.timerName, startedAt: $0.startedAt, minutes: $0.minutes)
        }
        let today = entries.filter { Calendar.current.isDateInToday($0.startedAt) }
        VStack(spacing: ShellMetrics.margin) {
        headerBar
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(today: today)
                cards(today: today)
                PomodoroHistoryView(entries: entries, timers: timers)
                    .id("history")
            }
            .frame(maxWidth: ShellMetrics.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 56)
            .themedScrollBars()
        }
        .scrollIndicators(.automatic)
        #if DEBUG
        .task {
            // Screenshots only: wait for the first layout, then show the history.
            guard DemoData.isEnabled, DemoData.showsPomodoroHistory || DemoData.showsPomodoroYear else { return }
            try? await Task.sleep(for: .milliseconds(800))
            proxy.scrollTo("history", anchor: .bottom)
        }
        #endif
        }
        }
        .background(hiddenShortcuts)
        #if DEBUG
        .task {
            guard DemoData.isEnabled, DemoData.opensNewTimer else { return }
            try? await Task.sleep(for: .milliseconds(600))
            isAdding = true
        }
        #endif
    }

    // MARK: Header

    private func header(today: [PomodoroHistory.Entry]) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.schemaLabel)
                    .tracking(0.88)
                    .foregroundStyle(SchemaTheme.inkMuted)
                Text("Pomodoro")
                    .font(.schemaDisplay)
                    .foregroundStyle(SchemaTheme.ink)
                Text(summary(today: today))
                    .font(.satoshi(13, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.inkMuted)
            }
        }
    }

    /// The header island (#116): where you are, then New timer.
    private var headerBar: some View {
        HeaderIsland {
            Text("Views")
            Text("/").foregroundStyle(SchemaTheme.inkFaint)
            Text("Pomodoro").foregroundStyle(SchemaTheme.ink)
        } trailing: {
            Button {
                isAdding.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    Text("New timer")
                    Text("⌘T").font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2)).opacity(0.7)
                }
            }
            .buttonStyle(.schema(.primary))
            .keyboardShortcut("t", modifiers: .command)
            .help("New timer  ⌘T")
            .popover(isPresented: $isAdding, arrowEdge: .bottom) {
                NewTimerForm(pages: pages) { choice in
                    runner.start(
                        name: choice.name,
                        focusMinutes: choice.focusMinutes,
                        breakMinutes: choice.breakMinutes,
                        automatic: choice.automatic,
                        linkedPageID: choice.pageID
                    )
                    isAdding = false
                } onCancel: {
                    isAdding = false
                }
            }
        }
    }

    private func summary(today: [PomodoroHistory.Entry]) -> String {
        let running = timers.filter(\.isRunning).count
        var parts: [String] = []
        if !timers.isEmpty { parts.append("\(running) running") }
        let minutes = today.reduce(0) { $0 + $1.minutes }
        parts.append(minutes == 0 ? "Nothing focused yet today" : "\(PomodoroHistory.duration(minutes)) focused today")
        if !today.isEmpty { parts.append(today.count == 1 ? "1 session" : "\(today.count) sessions") }
        return parts.joined(separator: " · ")
    }

    // MARK: Timers

    @ViewBuilder
    private func cards(today: [PomodoroHistory.Entry]) -> some View {
        if timers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No timers yet")
                    .font(.satoshi(15, weight: .bold, relativeTo: .headline))
                Text("Start one with New timer (⌘T). Several can run at once, each with its own focus and break lengths.")
                    .font(.schemaControl)
                    .foregroundStyle(SchemaTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .schemaCard(padding: 18)
        } else {
            let target = spaceTarget
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                ForEach(timers) { timer in
                    PomodoroTimerCard(
                        timer: timer,
                        todaySessions: today.filter { $0.timerID == timer.id }.map(\.minutes),
                        linkedPage: timer.linkedPageID.flatMap { id in pages.first { $0.id == id } },
                        isSpaceTarget: timer.id == target?.id,
                        onOpenPage: onOpenPage
                    )
                }
            }
        }
    }

    /// The running timer that ends soonest; with none running, the first one.
    private var spaceTarget: PomodoroTimer? {
        let now = Date.now
        return timers.filter(\.isRunning).min { PomodoroEngine.remaining($0, at: now) < PomodoroEngine.remaining($1, at: now) }
            ?? timers.first
    }

    private var hiddenShortcuts: some View {
        Button("Pause or resume") {
            if let target = spaceTarget { runner.togglePause(target) }
        }
        .keyboardShortcut(.space, modifiers: [])
        .disabled(timers.isEmpty || isAdding)
        .hidden()
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

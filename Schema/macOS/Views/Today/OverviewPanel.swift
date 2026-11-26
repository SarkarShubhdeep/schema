//
//  OverviewPanel.swift
//  Schema
//
//  What the details panel shows when no task is open: upcoming reminders,
//  completions this week as a small bar chart, and today's routines.
//

import SwiftUI

struct OverviewPanel: View {
    let stats: DayStats

    var body: some View {
        VStack(alignment: .leading, spacing: ShellMetrics.innerGap) {
            card(title: "Upcoming reminders", trailing: stats.reminders.isEmpty ? nil : "\(stats.reminders.count)") {
                if stats.reminders.isEmpty {
                    Text("No reminders coming up.")
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkMuted)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(stats.reminders.enumerated()), id: \.element.id) { index, reminder in
                            reminderRow(reminder)
                                .overlay(alignment: .top) {
                                    if index > 0 {
                                        Rectangle().fill(SchemaTheme.line).frame(height: 1)
                                    }
                                }
                        }
                    }
                }
            }

            card(title: "This week", trailing: "\(stats.weekTotal) done") {
                WeekChart(days: stats.week)
            }

            if !stats.routines.isEmpty {
                card(title: "Routines", trailing: nil) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(stats.routines) { routine in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(routine.title)
                                        .font(.schemaControl)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text("\(routine.done) / \(routine.total)")
                                        .font(.schemaMeta)
                                        .foregroundStyle(SchemaTheme.inkMuted)
                                }
                                SchemaProgressBar(
                                    value: Double(routine.done) / Double(max(routine.total, 1)),
                                    accessibilityText: "\(routine.title) routines"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func reminderRow(_ reminder: DayStats.Reminder) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(reminder.date.formatted(date: .omitted, time: .shortened))
                    .font(.schemaMeta)
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                Text(DayLabel.title(for: reminder.date))
                    .font(.spaceGrotesk(12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title)
                    .font(.schemaControl)
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(2)
                if let page = reminder.pageTitle {
                    Text(page)
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func card(title: String, trailing: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.spaceGrotesk(15, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(SchemaTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(.schemaMeta)
                        .foregroundStyle(SchemaTheme.inkMuted)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .schemaCard(padding: 16, cornerRadius: ShellMetrics.innerRadius, fill: SchemaTheme.islandCard, bordered: false)
    }
}

/// Completions per day this week. Past days in the strong line colour,
/// today in the accent, days still to come as flat stubs.
private struct WeekChart: View {
    let days: [DayStats.WeekDay]
    private let maxBarHeight: CGFloat = 56

    var body: some View {
        let peak = max(days.map(\.count).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.isFuture ? " " : "\(day.count)")
                        .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2).monospacedDigit())
                        .foregroundStyle(SchemaTheme.inkMuted)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(barColor(day))
                        .frame(maxWidth: 22)
                        .frame(height: barHeight(day, peak: peak))
                    Text(day.letter)
                        .font(.spaceGrotesk(11, weight: day.isToday ? .semibold : .medium, relativeTo: .caption2))
                        .foregroundStyle(day.isToday ? SchemaTheme.ink : SchemaTheme.inkMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: maxBarHeight + 40, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Tasks completed per day this week")
        .accessibilityValue(days.filter { !$0.isFuture }.map { "\($0.date.formatted(.dateTime.weekday(.wide))) \($0.count)" }.joined(separator: ", "))
    }

    private func barHeight(_ day: DayStats.WeekDay, peak: Int) -> CGFloat {
        if day.isFuture || day.count == 0 { return 4 }
        return max(6, maxBarHeight * CGFloat(day.count) / CGFloat(peak))
    }

    private func barColor(_ day: DayStats.WeekDay) -> Color {
        if day.isToday { return day.count == 0 ? SchemaTheme.surfaceHover : SchemaTheme.accent }
        if day.isFuture || day.count == 0 { return SchemaTheme.surfaceHover }
        return SchemaTheme.lineStrong
    }
}

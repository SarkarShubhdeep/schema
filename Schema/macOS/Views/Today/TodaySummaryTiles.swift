//
//  TodaySummaryTiles.swift
//  Schema
//
//  The row of stat tiles at the top of Today: Done today (with the only
//  progress bar), Due today with the next time, and This week.
//

import SwiftUI

struct TodaySummaryTiles: View {
    let stats: DayStats

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { tiles }
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) { tiles }
        }
    }

    @ViewBuilder
    private var tiles: some View {
        tile(label: "Done today") {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(stats.doneToday)")
                    .font(.schemaNumeral)
                Text(" / \(stats.totalToday)")
                    .font(.spaceGrotesk(15, weight: .regular, relativeTo: .body).monospacedDigit())
                    .foregroundStyle(SchemaTheme.inkMuted)
            }
            SchemaProgressBar(
                value: stats.totalToday == 0 ? 0 : Double(stats.doneToday) / Double(stats.totalToday),
                accessibilityText: "\(stats.doneToday) of \(stats.totalToday) done today"
            )
        }

        tile(label: "Due today") {
            Text("\(stats.dueToday)")
                .font(.schemaNumeral)
            Text(nextDueNote)
                .font(.schemaCaption)
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
        }

        tile(label: "This week") {
            Text("\(stats.weekTotal)")
                .font(.schemaNumeral)
            Text(stats.weekTotal == 1 ? "Task completed" : "Tasks completed")
                .font(.schemaCaption)
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
        }
    }

    private var nextDueNote: String {
        guard let next = stats.nextDueTime else {
            return stats.dueToday == 0 ? "All clear" : "No times left today"
        }
        return "Next at \(next.formatted(date: .omitted, time: .shortened))"
    }

    private func tile(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SchemaSectionLabel(label)
            content()
        }
        .foregroundStyle(SchemaTheme.ink)
        .frame(minWidth: 150, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .schemaCard(padding: 18)
        .accessibilityElement(children: .combine)
    }
}

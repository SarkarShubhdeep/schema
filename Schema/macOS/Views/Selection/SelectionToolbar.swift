//
//  SelectionToolbar.swift
//  Schema
//
//  Floating pill shown while tasks are selected: count, reschedule, move to
//  page, delete, Complete (⇧↩) and clear (Esc). Icons carry tooltips with
//  their shortcuts.
//

import SwiftUI

enum RescheduleOption: CaseIterable, Identifiable {
    case today
    case tomorrow
    case nextWeek
    case noDate

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next week"
        case .noDate: "No date"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .tomorrow: "sunrise"
        case .nextWeek: "calendar"
        case .noDate: "calendar.badge.minus"
        }
    }

    /// New due date for a task, keeping its time of day (9:00 AM if it had none).
    func date(keepingTimeOf current: Date?, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        let day: Date?
        switch self {
        case .today: day = startOfToday
        case .tomorrow: day = calendar.date(byAdding: .day, value: 1, to: startOfToday)
        case .nextWeek:
            // The coming Monday.
            day = calendar.nextDate(after: startOfToday, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)
        case .noDate: return nil
        }
        guard let day else { return nil }
        let time = current.map { calendar.dateComponents([.hour, .minute], from: $0) }
            ?? DateComponents(hour: 9, minute: 0)
        return calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: day)
    }
}

struct SelectionToolbar: View {
    let count: Int
    /// All selected tasks are done: the main button reopens them instead.
    let isAllCompleted: Bool
    let pages: [SchemaList]
    let onReschedule: (RescheduleOption) -> Void
    let onMove: (SchemaList) -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count) selected")
                .font(.spaceGrotesk(14, weight: .medium, relativeTo: .body).monospacedDigit())
                .fixedSize()
                .padding(.trailing, 8)

            SchemaMenuButton("Reschedule") {
                SchemaMenuItem.header("Reschedule")
                for option in RescheduleOption.allCases {
                    SchemaMenuItem.action(option.title) { onReschedule(option) }
                }
            } label: {
                toolbarIcon("calendar")
            }
            .fixedSize()
            .help("Reschedule")

            SchemaMenuButton("Move to page") {
                SchemaMenuItem.header("Move to")
                for page in pages {
                    SchemaMenuItem.action(page.title) { onMove(page) }
                }
            } label: {
                toolbarIcon("arrow.right")
            }
            .fixedSize()
            .disabled(pages.isEmpty)
            .help("Move to page")

            Button(action: onDelete) {
                toolbarIcon("trash")
            }
            .buttonStyle(.plain)
            .help("Delete  ⌫")
            .accessibilityLabel("Delete")

            Button(action: onComplete) {
                HStack(spacing: 8) {
                    Text(isAllCompleted ? "Reopen" : "Complete")
                        .font(.satoshi(14, weight: .bold, relativeTo: .callout))
                    Text("⇧↩")
                        .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(SchemaTheme.onAccent.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                }
                .foregroundStyle(SchemaTheme.onAccent)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Capsule(style: .continuous).fill(SchemaTheme.accent))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .help(isAllCompleted ? "Reopen  ⇧↩" : "Complete  ⇧↩")

            Button(action: onClear) {
                toolbarIcon("xmark", size: 12)
            }
            .buttonStyle(.plain)
            .help("Clear selection  Esc")
            .accessibilityLabel("Clear selection")
        }
        .foregroundStyle(SchemaTheme.canvas)
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 56)
        .background(
            Capsule(style: .continuous)
                .fill(SchemaTheme.ink)
                .shadow(color: .black.opacity(0.22), radius: 16, y: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected tasks")
    }

    private func toolbarIcon(_ systemImage: String, size: CGFloat = 15) -> some View {
        ToolbarIcon(systemImage: systemImage, size: size)
    }
}

private struct ToolbarIcon: View {
    let systemImage: String
    let size: CGFloat
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(SchemaTheme.canvas)
            .frame(width: 40, height: 40)
            .background(Circle().fill(SchemaTheme.canvas.opacity(isHovered ? 0.14 : 0)))
            .contentShape(Circle())
            .onHover { isHovered = $0 }
            .animation(SchemaMotion.fast, value: isHovered)
    }
}

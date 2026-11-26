//
//  TaskPagePanel.swift
//  Schema
//
//  The right panel while a task page is open (#31): Properties (page, due,
//  reminder, routine, after, tags), Checklist progress, where the task is
//  linked from, and its dates. Property changes save as they're made.
//

import SwiftData
import SwiftUI

struct TaskPagePanel: View {
    let task: SchemaTask
    @Bindable var editor: TaskDetailEditor
    let taskPages: [SchemaList]
    let sequenceCandidates: [SchemaTask]
    let allTasks: [SchemaTask]
    let calendar: Calendar
    /// Saves the draft's schedule to the task.
    let onSaveSchedule: () -> Void
    let onMove: (SchemaList) -> Void

    /// Scratchpads, to find the one this task was made from.
    @Query(filter: #Predicate<SchemaList> { $0.linkedTaskIDsRaw != "" }) private var linkingPages: [SchemaList]

    init(
        task: SchemaTask,
        editor: TaskDetailEditor,
        taskPages: [SchemaList],
        sequenceCandidates: [SchemaTask],
        allTasks: [SchemaTask],
        calendar: Calendar,
        onSaveSchedule: @escaping () -> Void,
        onMove: @escaping (SchemaList) -> Void
    ) {
        self.task = task
        self.editor = editor
        self.taskPages = taskPages
        self.sequenceCandidates = sequenceCandidates
        self.allTasks = allTasks
        self.calendar = calendar
        self.onSaveSchedule = onSaveSchedule
        self.onMove = onMove
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShellMetrics.innerGap) {
            card(title: "Properties", trailing: nil) {
                TaskPropertiesList(
                    task: task,
                    editor: editor,
                    taskPages: taskPages,
                    sequenceCandidates: sequenceCandidates,
                    allTasks: allTasks,
                    onSaveSchedule: onSaveSchedule,
                    onMove: onMove
                )
            }

            let steps = task.checklistCount
            if steps > 0 {
                let done = task.checklistDoneCount
                card(title: "Checklist", trailing: "\(done) of \(steps)") {
                    SchemaProgressBar(
                        value: Double(done) / Double(steps),
                        accessibilityText: "Checklist"
                    )
                    Text("To-do lines in a task are its steps. They don't show on Today.")
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            card(title: "Linked", trailing: nil) {
                detailGrid([
                    ("Made from", madeFrom),
                    ("Shows on", showsOn),
                ])
            }

            card(title: "Details", trailing: nil) {
                detailGrid([
                    ("Created", task.createdAt.formatted(date: .abbreviated, time: .omitted)),
                    ("Edited", edited),
                    ("Completed", task.completedAt.map { DayLabel.title(for: $0) } ?? (task.isCompleted ? "Yes" : "Not yet")),
                ])
            }
        }
    }

    // MARK: Values

    private var madeFrom: String {
        if let page = linkingPages.first(where: { $0.linkedTaskIDsRaw.contains(task.id.uuidString) }) {
            return "\(page.title) (scratchpad)"
        }
        return "Added in \(task.list?.title ?? "a page")"
    }

    private var showsOn: String {
        let now = Date.now
        var places = SmartView.allCases.filter { $0.includes(task, now: now, calendar: calendar) }.map(\.title)
        if let page = task.list?.title { places.append(page) }
        return places.joined(separator: ", ")
    }

    private var edited: String {
        guard let latest = task.documentEditedAt else { return "—" }
        return latest.formatted(.relative(presentation: .named))
    }

    // MARK: Layout

    private func detailGrid(_ rows: [(String, String)]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(rows, id: \.0) { row in
                GridRow {
                    Text(row.0)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .fixedSize()
                    Text(row.1)
                        .foregroundStyle(SchemaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.satoshi(13, relativeTo: .callout))
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

/// Label and value rows: Page, Due, Reminder, Routine, After, Tags.
private struct TaskPropertiesList: View {
    let task: SchemaTask
    @Bindable var editor: TaskDetailEditor
    let taskPages: [SchemaList]
    let sequenceCandidates: [SchemaTask]
    let allTasks: [SchemaTask]
    let onSaveSchedule: () -> Void
    let onMove: (SchemaList) -> Void

    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var pickerDate = Date()
    @State private var pickerTime = Date()

    private var draft: TaskDetailDraft { editor.draft }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row("Page", systemImage: "checklist") {
                SchemaMenuButton("Page") {
                    SchemaMenuItem.header("Move to")
                    for page in taskPages {
                        SchemaMenuItem.action(page.title, isChecked: page.id == task.list?.id) {
                            if page.id != task.list?.id { onMove(page) }
                        }
                    }
                } label: {
                    valueText(task.list?.title ?? "None", isSet: task.list != nil)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            row("Due", systemImage: "calendar") {
                HStack(spacing: 10) {
                    Button { openDatePicker() } label: {
                        valueText(dateLabel, isSet: draft.selectedDate != nil)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.isRoutine)
                    .help(draft.isRoutine ? "A routine repeats on its days" : "Set a date")
                    .popover(isPresented: $showDatePicker) { datePicker }

                    Button { openTimePicker() } label: {
                        valueText(timeLabel, isSet: draft.selectedTime != nil)
                    }
                    .buttonStyle(.plain)
                    .help("Set a time")
                    .popover(isPresented: $showTimePicker) { timePicker }
                }
            }

            row("Reminder", systemImage: "bell") {
                valueText(draft.selectedTime == nil ? "None" : "At due time", isSet: draft.selectedTime != nil)
            }

            row("Routine", systemImage: "repeat") {
                HStack(spacing: 8) {
                    valueText(draft.isRoutine ? routineSummary : "Off", isSet: draft.isRoutine)
                    Spacer(minLength: 0)
                    Toggle("Routine", isOn: Binding(
                        get: { draft.isRoutine },
                        set: { isOn in
                            if isOn { editor.draft.enableRoutine() } else { editor.draft.disableRoutine() }
                            onSaveSchedule()
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(SchemaTheme.ink)
                }
            }

            // The days get a full-width row so they never push the card wider.
            if draft.isRoutine {
                HStack(spacing: 0) {
                    ForEach(Array(WeekdayInfo.ordered.enumerated()), id: \.element.weekday) { index, day in
                        if index > 0 { Spacer(minLength: 2) }
                        dayButton(day)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                row("After", systemImage: "arrow.turn.down.right") {
                    SchemaMenuButton("After") {
                        SchemaMenuItem.action("None", isChecked: editor.draft.afterTaskID == nil) {
                            editor.draft.afterTaskID = nil
                            onSaveSchedule()
                        }
                        SchemaMenuItem.divider
                        for candidate in afterCandidates {
                            SchemaMenuItem.action(candidate.title, isChecked: editor.draft.afterTaskID == candidate.id) {
                                editor.draft.afterTaskID = candidate.id
                                onSaveSchedule()
                            }
                        }
                    } label: {
                        valueText(afterTitle ?? "None", isSet: afterTitle != nil)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            row("Tags", systemImage: "number") {
                valueText(task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "), isSet: !task.tags.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Rows

    private enum Metrics {
        /// Label column; values all start at the same x.
        static let labelWidth: CGFloat = 96
        static let rowHeight: CGFloat = 30
    }

    private func row(_ name: String, systemImage: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(spacing: 8) {
            Label {
                Text(name)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14)
            }
            .font(.satoshi(13, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.inkMuted)
            .lineLimit(1)
            .frame(width: Metrics.labelWidth, alignment: .leading)

            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Metrics.rowHeight)
    }

    private func valueText(_ text: String, isSet: Bool) -> some View {
        Text(text)
            .font(.satoshi(13, relativeTo: .callout).monospacedDigit())
            .foregroundStyle(isSet ? SchemaTheme.ink : SchemaTheme.inkMuted)
            .lineLimit(1)
            .truncationMode(.tail)
            .contentShape(Rectangle())
    }

    private func dayButton(_ day: WeekdayInfo) -> some View {
        let isOn = draft.isDaySelected(day.weekday)
        return Button {
            editor.draft.toggleDay(day.weekday)
            onSaveSchedule()
        } label: {
            Text(day.shortLabel)
                .font(.spaceGrotesk(10, weight: .semibold))
                .frame(width: 22, height: 22)
                .foregroundStyle(isOn ? SchemaTheme.canvas : SchemaTheme.inkMuted)
                .background(Circle().fill(isOn ? SchemaTheme.ink : .clear))
                .overlay(Circle().strokeBorder(isOn ? .clear : SchemaTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(day.fullName)
        .accessibilityLabel(day.fullName)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: Values

    private var dateLabel: String {
        if draft.isRoutine { return "Repeats" }
        guard let date = draft.selectedDate else { return draft.selectedTime == nil ? "Add a date" : "Next" }
        return DayLabel.title(for: date)
    }

    private var timeLabel: String {
        draft.selectedTime?.formatted(date: .omitted, time: .shortened) ?? "Add a time"
    }

    private var routineSummary: String {
        let days = draft.routineDays
        if days.count == 7 { return "Every day" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days == [1, 7] { return "Weekends" }
        if days.count > 3 { return "\(days.count) days" }
        return WeekdayInfo.ordered.filter { days.contains($0.weekday) }.map { String($0.fullName.prefix(3)) }.joined(separator: ", ")
    }

    private var afterCandidates: [SchemaTask] {
        RoutineSequenceOrdering.validAfterCandidates(
            for: editor.taskID,
            title: task.title,
            reminderTime: draft.computedReminderDate,
            candidates: sequenceCandidates,
            in: allTasks
        )
    }

    private var afterTitle: String? {
        guard let id = draft.afterTaskID else { return nil }
        return allTasks.first { $0.id == id }?.title
    }

    // MARK: Pickers

    private func openDatePicker() {
        pickerDate = draft.selectedDate ?? Date()
        showDatePicker = true
    }

    private func openTimePicker() {
        pickerTime = draft.selectedTime ?? Date().addingTimeInterval(3600)
        showTimePicker = true
    }

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Date", selection: $pickerDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.graphical)
            HStack {
                if draft.selectedDate != nil {
                    Button("Remove", role: .destructive) {
                        editor.draft.selectedDate = nil
                        showDatePicker = false
                        onSaveSchedule()
                    }
                }
                Spacer()
                Button("Cancel") { showDatePicker = false }
                Button("Done") {
                    editor.draft.selectedDate = pickerDate
                    if editor.draft.selectedTime == nil {
                        // A due date needs a time; start at 9 AM.
                        editor.draft.selectedTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: pickerDate)
                    }
                    showDatePicker = false
                    onSaveSchedule()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .fixedSize()
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Time", selection: $pickerTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.stepperField)
            HStack {
                if draft.selectedTime != nil {
                    Button("Remove", role: .destructive) {
                        editor.draft.clearReminder()
                        showTimePicker = false
                        onSaveSchedule()
                    }
                }
                Spacer()
                Button("Cancel") { showTimePicker = false }
                Button("Done") {
                    editor.draft.selectedTime = pickerTime
                    showTimePicker = false
                    onSaveSchedule()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .fixedSize()
    }
}

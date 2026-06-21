//
//  TaskDetailSheet.swift
//  Schema
//

import AppKit
import Observation
import SwiftUI

struct WeekdayInfo {
    let weekday: Int
    let shortLabel: String
    let fullName: String

    static let ordered: [WeekdayInfo] = [
        WeekdayInfo(weekday: 2, shortLabel: "M", fullName: "Monday"),
        WeekdayInfo(weekday: 3, shortLabel: "T", fullName: "Tuesday"),
        WeekdayInfo(weekday: 4, shortLabel: "W", fullName: "Wednesday"),
        WeekdayInfo(weekday: 5, shortLabel: "T", fullName: "Thursday"),
        WeekdayInfo(weekday: 6, shortLabel: "F", fullName: "Friday"),
        WeekdayInfo(weekday: 7, shortLabel: "S", fullName: "Saturday"),
        WeekdayInfo(weekday: 1, shortLabel: "S", fullName: "Sunday"),
    ]

    static var allWeekdays: Set<Int> {
        Set(ordered.map(\.weekday))
    }
}

struct TaskDetailDraft {
    var title: String
    var description: String
    var selectedTime: Date?
    var selectedDate: Date?
    var isRoutine: Bool
    var routineDays: Set<Int>
    var afterTaskID: UUID?

    var hasReminder: Bool {
        selectedTime != nil
    }

    var computedReminderDate: Date? {
        guard let time = selectedTime else { return nil }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        if isRoutine {
            return time
        }

        if let date = selectedDate {
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            return calendar.date(from: dateComponents)
        } else {
            return Self.nextOccurrence(hour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0)
        }
    }

    init(task: SchemaTask) {
        title = task.title
        description = task.taskDescription ?? ""
        isRoutine = task.isRoutine
        afterTaskID = task.afterTaskID

        if task.isRoutine {
            routineDays = task.routineDays.isEmpty
                ? WeekdayInfo.allWeekdays
                : Set(task.routineDays)
        } else {
            routineDays = Set(task.routineDays)
        }

        if let reminder = task.reminderTime {
            selectedTime = reminder
            selectedDate = isRoutine ? nil : reminder
        } else {
            selectedTime = nil
            selectedDate = nil
        }
    }

    var normalizedRoutineDays: [Int] {
        Array(routineDays).sorted()
    }

    mutating func enableRoutine() {
        isRoutine = true
        if routineDays.isEmpty {
            routineDays = WeekdayInfo.allWeekdays
        }
    }

    mutating func disableRoutine() {
        isRoutine = false
        afterTaskID = nil
    }

    mutating func clearReminder() {
        selectedTime = nil
        selectedDate = nil
    }

    func isDaySelected(_ weekday: Int) -> Bool {
        routineDays.contains(weekday)
    }

    mutating func toggleDay(_ weekday: Int) {
        if routineDays.contains(weekday) {
            routineDays.remove(weekday)
        } else {
            routineDays.insert(weekday)
        }
    }

    static func nextOccurrence(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let todayAtTime = calendar.date(from: components) else {
            return now
        }

        if todayAtTime > now {
            return todayAtTime
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayAtTime) ?? todayAtTime
        }
    }
}

@Observable
@MainActor
final class TaskDetailEditor {
    let taskID: UUID
    var draft: TaskDetailDraft

    init(task: SchemaTask) {
        taskID = task.id
        draft = TaskDetailDraft(task: task)
    }
}

final class TaskDetailPanelHostView: NSView {}

private struct TaskDetailPanelHostRepresentable: NSViewRepresentable {
    let onCloseRequest: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCloseRequest: onCloseRequest)
    }

    func makeNSView(context: Context) -> TaskDetailPanelHostView {
        let view = TaskDetailPanelHostView()
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: TaskDetailPanelHostView, context: Context) {
        context.coordinator.onCloseRequest = onCloseRequest
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var onCloseRequest: () -> Void
        private var monitor: Any?

        init(onCloseRequest: @escaping () -> Void) {
            self.onCloseRequest = onCloseRequest
        }

        func installMonitor() {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                // Return / Enter with Command — save and close
                if event.keyCode == 36, event.modifierFlags.contains(.command) {
                    DispatchQueue.main.async {
                        self.onCloseRequest()
                    }
                    return nil
                }

                // Escape — save and close
                if event.keyCode == 53 {
                    DispatchQueue.main.async {
                        self.onCloseRequest()
                    }
                    return nil
                }

                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            removeMonitor()
        }
    }
}

struct TaskDetailSheet: View {
    @Bindable var editor: TaskDetailEditor
    let listTagLabel: String?
    let sequenceCandidates: [SchemaTask]
    let allTasks: [SchemaTask]
    let isCompleted: Bool
    let onCloseRequest: () -> Void
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void
    let onClearFollowerTimes: ([UUID]) -> Void

    @FocusState private var focusedField: Field?
    @State private var showTimePicker = false
    @State private var showDatePicker = false
    @State private var pickerTime = Date()
    @State private var pickerDate = Date()

    private enum Field: Hashable {
        case title
        case description
    }

    private enum Metrics {
        static let width: CGFloat = 460
        static let cornerRadius: CGFloat = 20
        static let descriptionMinHeight: CGFloat = 120
        static let metadataSectionSpacing: CGFloat = 18
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleField

            metadataRow
                .padding(.top, 20)

            if let listTagLabel {
                listTag(label: listTagLabel)
                    .padding(.top, Metrics.metadataSectionSpacing)
            }

            routineRow
                .padding(.top, Metrics.metadataSectionSpacing)

            if editor.draft.isRoutine {
                afterRow
                    .padding(.top, Metrics.metadataSectionSpacing)
            }

            if let sequenceValidation {
                sequenceValidationBanner(sequenceValidation)
                    .padding(.top, Metrics.metadataSectionSpacing)
            }

            descriptionSection
                .padding(.top, 22)

            footerActions
                .padding(.top, 28)
        }
        .padding(24)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: Metrics.width)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(SchemaTheme.controlFill)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                        .strokeBorder(SchemaTheme.divider, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        )
        .background(TaskDetailPanelHostRepresentable(onCloseRequest: onCloseRequest))
        .defaultFocus($focusedField, .title)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .title
            }
        }
        .onChange(of: afterPickerInvalidationKey) { _, _ in
            reconcileAfterSelection()
        }
    }

    private var afterPickerInvalidationKey: String {
        let timeKey = editor.draft.selectedTime?.timeIntervalSinceReferenceDate ?? -1
        return "\(editor.draft.title)-\(timeKey)-\(editor.draft.isRoutine)"
    }

    private func reconcileAfterSelection() {
        guard let selectedAfterID = editor.draft.afterTaskID else { return }
        if !timeValidAfterCandidates.contains(where: { $0.id == selectedAfterID }) {
            editor.draft.afterTaskID = nil
        }
    }

    private var titleField: some View {
        TextField("Task title", text: $editor.draft.title, axis: .vertical)
            .font(.system(size: 24, weight: .bold))
            .textFieldStyle(.plain)
            .lineLimit(3)
            .focused($focusedField, equals: .title)
    }

    private var metadataRow: some View {
        HStack(spacing: 20) {
            timeControl
            dateControl
        }
    }

    private var timeControl: some View {
        Button {
            pickerTime = editor.draft.selectedTime ?? Date().addingTimeInterval(3600)
            showTimePicker = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .medium))

                Text(timeLabel)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(editor.draft.selectedTime != nil ? SchemaTheme.accent : SchemaTheme.mutedText)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTimePicker) {
            timePickerContent
        }
    }

    private var timeLabel: String {
        if let time = editor.draft.selectedTime {
            return time.formatted(date: .omitted, time: .shortened)
        }
        return "Add time"
    }

    private var dateControl: some View {
        Button {
            pickerDate = editor.draft.selectedDate ?? Date()
            showDatePicker = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .medium))

                Text(dateLabel)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(
                editor.draft.isRoutine
                    ? SchemaTheme.mutedText.opacity(0.4)
                    : (editor.draft.selectedDate != nil ? SchemaTheme.accent : SchemaTheme.mutedText)
            )
        }
        .buttonStyle(.plain)
        .disabled(editor.draft.isRoutine)
        .help(editor.draft.isRoutine ? "Date is managed by routine schedule" : "Add date")
        .popover(isPresented: $showDatePicker) {
            datePickerContent
        }
    }

    private var dateLabel: String {
        if editor.draft.isRoutine {
            return "Repeats"
        }
        if let date = editor.draft.selectedDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                let year = calendar.component(.year, from: date)
                let nowYear = calendar.component(.year, from: Date())
                if year == nowYear {
                    return date.formatted(.dateTime.month(.abbreviated).day())
                } else {
                    return date.formatted(.dateTime.month(.abbreviated).day().year())
                }
            }
        }
        return "Add date"
    }

    private var routineRow: some View {
        HStack(spacing: 12) {
            Toggle(isOn: routineToggleBinding) {
                HStack(spacing: 5) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Routine")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(SchemaTheme.accent)

            if editor.draft.isRoutine {
                Spacer()
                daySelector
            }
        }
    }

    private var routineToggleBinding: Binding<Bool> {
        Binding(
            get: { editor.draft.isRoutine },
            set: { isOn in
                if isOn {
                    editor.draft.enableRoutine()
                } else {
                    editor.draft.disableRoutine()
                }
            }
        )
    }

    private var afterRow: some View {
        HStack(spacing: 10) {
            Text("After")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SchemaTheme.mutedText)

            Picker("After", selection: $editor.draft.afterTaskID) {
                Text("None").tag(UUID?.none)

                ForEach(timeValidAfterCandidates, id: \.id) { candidate in
                    Text(candidate.title).tag(Optional(candidate.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timeValidAfterCandidates: [SchemaTask] {
        RoutineSequenceOrdering.validAfterCandidates(
            for: editor.taskID,
            title: editor.draft.title,
            reminderTime: editor.draft.computedReminderDate,
            candidates: sequenceCandidates,
            in: allTasks
        )
    }

    private var sequenceValidation: RoutineSequenceValidationResult? {
        RoutineSequenceOrdering.validateProposedSequenceState(
            for: editor.taskID,
            title: editor.draft.title,
            isRoutine: editor.draft.isRoutine,
            afterTaskID: editor.draft.afterTaskID,
            reminderTime: editor.draft.computedReminderDate,
            in: allTasks
        )
    }

    private func sequenceValidationBanner(_ validation: RoutineSequenceValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(validation.message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)

            Text(validation.suggestion)
                .font(.system(size: 11))
                .foregroundStyle(SchemaTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            Button("Remove follower times") {
                removeFollowerTimes()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(SchemaTheme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func removeFollowerTimes() {
        let followerIDs = RoutineSequenceOrdering.followerIDsInProposedChain(
            containing: editor.taskID,
            title: editor.draft.title,
            isRoutine: editor.draft.isRoutine,
            afterTaskID: editor.draft.afterTaskID,
            reminderTime: editor.draft.computedReminderDate,
            in: allTasks
        )

        guard !followerIDs.isEmpty else { return }

        if followerIDs.contains(editor.taskID) {
            editor.draft.clearReminder()
        }

        let otherFollowerIDs = followerIDs.filter { $0 != editor.taskID }
        if !otherFollowerIDs.isEmpty {
            onClearFollowerTimes(otherFollowerIDs)
        }
    }

    private var daySelector: some View {
        HStack(spacing: 6) {
            ForEach(Array(WeekdayInfo.ordered.enumerated()), id: \.element.weekday) { _, info in
                dayButton(for: info)
            }
        }
    }

    private func dayButton(for info: WeekdayInfo) -> some View {
        let isSelected = editor.draft.isDaySelected(info.weekday)
        return Button {
            editor.draft.toggleDay(info.weekday)
        } label: {
            Text(info.shortLabel)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(isSelected ? .white : SchemaTheme.mutedText)
                .background(
                    Circle()
                        .fill(isSelected ? SchemaTheme.accent : Color.clear)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.clear : SchemaTheme.mutedText.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(info.fullName)
    }

    private func listTag(label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SchemaTheme.mutedText.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(SchemaTheme.countBadgeBackground)
            )
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.subheadline)
                .foregroundStyle(SchemaTheme.mutedText)

            TextEditor(text: $editor.draft.description)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: Metrics.descriptionMinHeight)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SchemaTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(SchemaTheme.divider, lineWidth: 1)
                )
                .focused($focusedField, equals: .description)
        }
    }

    private var footerActions: some View {
        HStack(spacing: 16) {
            Button(action: onToggleCompletion) {
                HStack(spacing: 6) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))

                    Text(isCompleted ? "Mark as incomplete" : "Mark as completed")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(isCompleted ? SchemaTheme.accent : SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)
            .help(isCompleted ? "Mark as incomplete" : "Mark as completed")

            Spacer()

            Button {} label: {
                Image(systemName: "archivebox")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(SchemaTheme.mutedText.opacity(0.45))
            }
            .buttonStyle(.plain)
            .disabled(true)
            .help("Archive (coming soon)")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)
            .help("Delete task")
        }
    }

    private var timePickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Time")
                .font(.headline)

            DatePicker(
                "Time",
                selection: $pickerTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.stepperField)

            if editor.draft.selectedDate == nil {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: pickerTime)
                let nextDate = TaskDetailDraft.nextOccurrence(
                    hour: timeComponents.hour ?? 0,
                    minute: timeComponents.minute ?? 0
                )
                let dayText = calendar.isDateInToday(nextDate) ? "today" : "tomorrow"
                Text("Reminder will be set for \(dayText) at \(pickerTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(SchemaTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Cancel") {
                    showTimePicker = false
                }

                if editor.draft.selectedTime != nil {
                    Button("Remove", role: .destructive) {
                        editor.draft.selectedTime = nil
                        editor.draft.selectedDate = nil
                        showTimePicker = false
                    }
                }

                Spacer()

                Button("Done") {
                    editor.draft.selectedTime = pickerTime
                    showTimePicker = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .fixedSize()
    }

    private var datePickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Date")
                .font(.headline)

            DatePicker(
                "Date",
                selection: $pickerDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)

            HStack {
                Button("Cancel") {
                    showDatePicker = false
                }

                if editor.draft.selectedDate != nil {
                    Button("Remove", role: .destructive) {
                        editor.draft.selectedDate = nil
                        showDatePicker = false
                    }
                }

                Spacer()

                Button("Done") {
                    editor.draft.selectedDate = pickerDate
                    showDatePicker = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .fixedSize()
    }
}

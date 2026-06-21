//
//  AddTaskBar.swift
//  Schema
//

import SwiftUI

struct AddTaskBar: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    let placeholder: String
    var parsedMentions: ParsedAtMentions?
    @Binding var selectedListCandidateIndex: Int
    let onSubmit: () -> Void
    let onCancel: () -> Void
    var onOpen: (() -> Void)?
    var onNavigateUp: (() -> Void)?
    var onNavigateDown: (() -> Void)?
    var focusBinding: FocusState<Bool>.Binding

    private enum Metrics {
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 10
        static let contentHeight: CGFloat = 22
        static var controlHeight: CGFloat {
            contentHeight + (verticalPadding * 2)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if isExpanded {
                expandedField
                    .transition(.opacity)
            } else {
                addTaskButton
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(SchemaTheme.background)
        .animation(SchemaMotion.fast, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                DispatchQueue.main.async {
                    focusBinding.wrappedValue = true
                }
            }
        }
    }

    private var addTaskButton: some View {
        Button(action: openAddTask) {
            addTaskContainer(showFocusBorder: false) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SchemaTheme.mutedText)

                Text("Add task")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SchemaTheme.mutedText)

                shortcutBadge
            }
        }
        .buttonStyle(.plain)
    }

    private var expandedField: some View {
        VStack(alignment: .leading, spacing: 6) {
            addTaskContainer(showFocusBorder: true) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SchemaTheme.mutedText)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .frame(height: Metrics.contentHeight)
                    .focused(focusBinding)
                    .onSubmit(onSubmit)
                    .onKeyPress(.escape) {
                        onCancel()
                        return .handled
                    }
                    .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { _ in
                        if shouldPrioritizeListSelection {
                            return moveListCandidateSelection(by: -1)
                        }
                        onNavigateUp?()
                        return .handled
                    }
                    .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { _ in
                        if shouldPrioritizeListSelection {
                            return moveListCandidateSelection(by: 1)
                        }
                        onNavigateDown?()
                        return .handled
                    }
                    .onChange(of: parsedMentions?.listCandidates.map(\.id) ?? []) { _, newIDs in
                        clampListCandidateSelection(candidateCount: newIDs.count)
                    }
            }

            if let parsedMentions, parsedMentions.hasPreviewContent {
                mentionPreview(parsedMentions)
                    .padding(.leading, Metrics.horizontalPadding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(SchemaMotion.fast, value: parsedMentions?.hasPreviewContent ?? false)
    }

    private var shouldPrioritizeListSelection: Bool {
        guard let parsedMentions else { return false }
        return parsedMentions.listCandidates.count > 1
    }

    private var selectedListCandidate: SchemaList? {
        parsedMentions?.resolvedList(at: selectedListCandidateIndex)
    }

    private func moveListCandidateSelection(by offset: Int) -> KeyPress.Result {
        guard let candidates = parsedMentions?.listCandidates, candidates.count > 1 else {
            return .ignored
        }

        let nextIndex = min(
            max(selectedListCandidateIndex + offset, 0),
            candidates.count - 1
        )
        guard nextIndex != selectedListCandidateIndex else { return .handled }

        withAnimation(SchemaMotion.fast) {
            selectedListCandidateIndex = nextIndex
        }
        return .handled
    }

    private func clampListCandidateSelection(candidateCount: Int) {
        guard candidateCount > 0 else {
            selectedListCandidateIndex = 0
            return
        }
        selectedListCandidateIndex = min(selectedListCandidateIndex, candidateCount - 1)
    }

    @ViewBuilder
    private func mentionPreview(_ mentions: ParsedAtMentions) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if mentions.hasResolvedMentions {
                mentionChipsRow(mentions)
            }

            if !mentions.listCandidates.isEmpty {
                listSuggestions(
                    mentions.listCandidates,
                    activePrefix: mentions.activeListPrefix,
                    selectedIndex: selectedListCandidateIndex
                )
            }
        }
    }

    private func mentionChipsRow(_ mentions: ParsedAtMentions) -> some View {
        HStack(spacing: 8) {
            if let time = mentions.detectedTime {
                mentionChip(
                    icon: "clock",
                    label: time.formatted(date: .omitted, time: .shortened),
                    accentColor: SchemaTheme.accent
                )
            }

            if let date = mentions.detectedDate {
                mentionChip(
                    icon: "calendar",
                    label: dateLabel(for: date),
                    accentColor: SchemaTheme.accent
                )
            }

            if let list = mentions.detectedList {
                mentionChip(
                    icon: nil,
                    label: list.displayTagLabel,
                    accentColor: SchemaTheme.listAccent(for: list),
                    showsListDot: true
                )
            } else if mentions.listCandidates.count > 1, let selected = selectedListCandidate {
                mentionChip(
                    icon: nil,
                    label: "\(selected.displayTagLabel) (selected)",
                    accentColor: SchemaTheme.listAccent(for: selected),
                    showsListDot: true
                )
            }
        }
    }

    private func listSuggestions(
        _ candidates: [SchemaList],
        activePrefix: String?,
        selectedIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let activePrefix {
                Text("Lists matching \"\(activePrefix)\" — ↑↓ to select")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SchemaTheme.mutedText)
            }

            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, list in
                Button {
                    withAnimation(SchemaMotion.fast) {
                        selectedListCandidateIndex = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(SchemaTheme.listAccent(for: list))
                            .frame(width: 6, height: 6)

                        Text(list.displayTagLabel)
                            .font(.system(size: 11, weight: index == selectedIndex ? .semibold : .medium))

                        if index == selectedIndex, candidates.count > 1 {
                            Text("selected")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(SchemaTheme.mutedText)
                        }
                    }
                    .foregroundStyle(index == selectedIndex ? SchemaTheme.accent : SchemaTheme.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(index == selectedIndex ? SchemaTheme.accent.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SchemaTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(SchemaTheme.divider, lineWidth: 1)
                )
        )
    }

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func mentionChip(
        icon: String?,
        label: String,
        accentColor: Color,
        showsListDot: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            if showsListDot {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func addTaskContainer<Content: View>(
        showFocusBorder: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .frame(height: Metrics.controlHeight, alignment: .leading)
        .padding(.horizontal, Metrics.horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SchemaTheme.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    showFocusBorder ? SchemaTheme.accent.opacity(0.45) : .clear,
                    lineWidth: 1.5
                )
        )
    }

    private var shortcutBadge: some View {
        Text("n")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(SchemaTheme.mutedText)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(SchemaTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(SchemaTheme.divider, lineWidth: 1)
                    )
            )
    }

    private func openAddTask() {
        onOpen?()
        isExpanded = true
    }
}

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            pill

            if let parsedMentions, parsedMentions.hasPreviewContent {
                mentionPreview(parsedMentions)
                    .padding(.leading, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(SchemaMotion.fast, value: parsedMentions?.hasPreviewContent ?? false)
        .animation(SchemaMotion.fast, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                DispatchQueue.main.async {
                    focusBinding.wrappedValue = true
                }
            }
        }
        .onChange(of: focusBinding.wrappedValue) { _, focused in
            if focused, !isExpanded {
                onOpen?()
                isExpanded = true
            }
        }
    }

    /// Full-width pill: plus, the field, the N hint at rest, and a send button.
    private var pill: some View {
        let canSubmit = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SchemaTheme.inkMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.satoshi(16, relativeTo: .body))
                .foregroundStyle(SchemaTheme.ink)
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

            if !isExpanded, text.isEmpty {
                SchemaKeyHint("N")
                    .transition(.opacity)
            }

            Button(action: onSubmit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SchemaTheme.canvas)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(SchemaTheme.ink))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(canSubmit ? 1 : 0.35)
            .disabled(!canSubmit)
            .help("Add task  Return")
            .accessibilityLabel("Add task")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(height: 56)
        .background(Capsule(style: .continuous).fill(SchemaTheme.surface))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(isExpanded ? SchemaTheme.ink : SchemaTheme.line, lineWidth: isExpanded ? 1.5 : 1)
        )
        .contentShape(Capsule(style: .continuous))
        .onTapGesture { openAddTask() }
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
                    accentColor: SchemaTheme.inkMuted
                )
            }

            if let date = mentions.detectedDate {
                mentionChip(
                    icon: "calendar",
                    label: dateLabel(for: date),
                    accentColor: SchemaTheme.inkMuted
                )
            }

            if let list = mentions.detectedList {
                mentionChip(
                    icon: nil,
                    label: list.displayTagLabel,
                    accentColor: SchemaTheme.inkMuted,
                    showsListDot: true
                )
            } else if mentions.listCandidates.count > 1, let selected = selectedListCandidate {
                mentionChip(
                    icon: nil,
                    label: "\(selected.displayTagLabel) (selected)",
                    accentColor: SchemaTheme.inkMuted,
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
                    .font(.satoshi(10, weight: .medium))
                    .foregroundStyle(SchemaTheme.inkMuted)
            }

            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, list in
                Button {
                    withAnimation(SchemaMotion.fast) {
                        selectedListCandidateIndex = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(SchemaTheme.inkMuted)
                            .frame(width: 6, height: 6)

                        Text(list.displayTagLabel)
                            .font(.satoshi(11, weight: index == selectedIndex ? .semibold : .medium))

                        if index == selectedIndex, candidates.count > 1 {
                            Text("selected")
                                .font(.satoshi(10, weight: .medium))
                                .foregroundStyle(SchemaTheme.inkMuted)
                        }
                    }
                    .foregroundStyle(index == selectedIndex ? SchemaTheme.ink : SchemaTheme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(index == selectedIndex ? SchemaTheme.surfaceHover : .clear)
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
                        .strokeBorder(SchemaTheme.line, lineWidth: 1)
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
                .font(.satoshi(11, weight: .medium))
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

    private func openAddTask() {
        onOpen?()
        isExpanded = true
    }
}

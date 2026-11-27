//
//  NewPageDialog.swift
//  Schema
//
//  New page (⌘N): a name and a page type, To-do list or Scratchpad (#37).
//  A card over the dimmed window, like the delete dialog. Esc or a click
//  outside cancels; Return creates.
//

import SwiftUI

struct NewPageDialog: View {
    @Binding var title: String
    @Binding var kind: PageKind
    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var createLabel: String {
        kind == .scratchpad ? "Create scratchpad" : "Create to-do list"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)

            card
                .padding(24)
        }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("New page")
                    .font(.spaceGrotesk(22, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(SchemaTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                        .foregroundStyle(SchemaTheme.ink)
                    TextField("", text: $title, prompt: Text(kind == .scratchpad ? "Side project ideas" : "Side project"))
                        .textFieldStyle(.plain)
                        .font(.satoshi(16, relativeTo: .body))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SchemaTheme.canvas)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isNameFocused ? SchemaTheme.focusRing : SchemaTheme.lineStrong, lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .onSubmit(createIfPossible)
                        .accessibilityLabel("Page name")
                }

                Text("Page type")
                    .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.ink)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            typeCards
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)

            Rectangle()
                .fill(SchemaTheme.line)
                .frame(height: 1)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: 760, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SchemaTheme.surface)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SchemaTheme.line, lineWidth: 1)
        )
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onAppear { isNameFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("New page")
    }

    /// Three cards side by side; they wrap onto more rows in a narrow window.
    private var typeCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 200), spacing: 12, alignment: .top)],
            alignment: .leading,
            spacing: 12
        ) {
            cards
        }
    }

    @ViewBuilder
    private var cards: some View {
        PageTypeCard(
            name: "To-do list",
            summary: "Tasks with checkboxes, reminders, routines and drag to reorder. Open tasks show on Today.",
            isSelected: kind == .todo,
            preview: { TodoPreview() }
        ) { kind = .todo }

        PageTypeCard(
            name: "Scratchpad",
            summary: "Free-form notes for ideas and drafts: text, headings, bullets, quotes. Any line can become a task.",
            isSelected: kind == .scratchpad,
            preview: { ScratchpadPreview() }
        ) { kind = .scratchpad }

        LaterTypesCard()
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("Adds to Pages in the sidebar")
                .font(.satoshi(13, relativeTo: .callout))
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCancel) {
                HStack(spacing: 8) {
                    Text("Cancel")
                    SchemaKeyHint("Esc")
                }
            }
            .buttonStyle(.schema(.ghost))
            .keyboardShortcut(.cancelAction)

            Button(createLabel, action: createIfPossible)
                .buttonStyle(.schema(.primary))
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedTitle.isEmpty)
        }
    }

    private func createIfPossible() {
        guard !trimmedTitle.isEmpty else { return }
        onCreate()
    }
}

// MARK: - Cards

private struct PageTypeCard<Preview: View>: View {
    let name: String
    let summary: String
    let isSelected: Bool
    @ViewBuilder let preview: () -> Preview
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview()
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SchemaTheme.canvas)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(SchemaTheme.line, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                HStack(spacing: 8) {
                    RadioDot(isOn: isSelected)
                    Text(name)
                        .font(.satoshi(15, weight: .bold, relativeTo: .body))
                        .foregroundStyle(SchemaTheme.ink)
                }

                Text(summary)
                    .font(.satoshi(13, relativeTo: .callout))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(minWidth: 200, maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isHovered && !isSelected ? SchemaTheme.surfaceHover.opacity(0.5) : SchemaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? SchemaTheme.lineStrong : SchemaTheme.line, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(SchemaMotion.fast, value: isSelected)
        .animation(SchemaMotion.fast, value: isHovered)
        .accessibilityLabel(name)
        .accessibilityHint(summary)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct LaterTypesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Table · Board · Calendar")
                .font(.satoshi(12, relativeTo: .caption))
                .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(SchemaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            Text("More page types later")
                .font(.satoshi(15, weight: .bold, relativeTo: .body))
            Text("Each type keeps a fixed structure, so pages stay quick to scan.")
                .font(.satoshi(13, relativeTo: .callout))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(SchemaTheme.inkMuted)
        .padding(12)
        .frame(minWidth: 200, maxWidth: .infinity, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SchemaTheme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("More page types later: table, board and calendar")
    }
}

private struct RadioDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .strokeBorder(isOn ? SchemaTheme.ink : SchemaTheme.lineStrong, lineWidth: isOn ? 5 : 1.5)
            .frame(width: 16, height: 16)
    }
}

/// Four checklist rows, drawn small.
private struct TodoPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach([0.6, 0.75, 0.45, 0.65], id: \.self) { width in
                HStack(spacing: 8) {
                    Circle()
                        .strokeBorder(SchemaTheme.lineStrong, lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(SchemaTheme.lineStrong.opacity(0.6))
                            .frame(width: proxy.size.width * width, height: 6)
                    }
                    .frame(height: 6)
                }
            }
        }
    }
}

/// A heading, two lines of text, a bullet and a to-do, drawn small.
private struct ScratchpadPreview: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(SchemaTheme.ink).frame(width: w * 0.45, height: 8)
                Capsule().fill(SchemaTheme.lineStrong.opacity(0.6)).frame(width: w * 0.92, height: 5)
                Capsule().fill(SchemaTheme.lineStrong.opacity(0.6)).frame(width: w * 0.8, height: 5)
                HStack(spacing: 6) {
                    Circle().fill(SchemaTheme.inkMuted).frame(width: 4, height: 4)
                    Capsule().fill(SchemaTheme.lineStrong.opacity(0.6)).frame(width: w * 0.55, height: 5)
                }
                HStack(spacing: 6) {
                    Circle().strokeBorder(SchemaTheme.lineStrong, lineWidth: 1.5).frame(width: 10, height: 10)
                    Capsule().fill(SchemaTheme.lineStrong.opacity(0.6)).frame(width: w * 0.4, height: 5)
                }
            }
        }
    }
}

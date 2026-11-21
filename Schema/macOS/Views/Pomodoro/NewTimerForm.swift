//
//  NewTimerForm.swift
//  Schema
//
//  New timer (#89, ⌘T): a name, the focus and break lengths, the page the
//  time counts toward, and whether breaks and sessions start by themselves.
//

import SwiftUI

struct NewTimerForm: View {
    struct Choice {
        var name: String
        var focusMinutes: Int
        var breakMinutes: Int
        var automatic: Bool
        var pageID: UUID?
    }

    let pages: [SchemaList]
    let onStart: (Choice) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var focus = 25
    @State private var isCustom = false
    @State private var customMinutes = "30"
    @State private var rest = 5
    @State private var automatic = true
    @State private var pageID: UUID?
    @FocusState private var isNameFocused: Bool

    private static let focusChoices = [25, 40, 50]
    private static let breakChoices = [5, 10, 15, 0]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Name") {
                TextField("What are you working on?", text: $name)
                    .textFieldStyle(.plain)
                    .font(.schemaControl)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule(style: .continuous).fill(SchemaTheme.canvas))
                    .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.lineStrong, lineWidth: 1))
                    .focused($isNameFocused)
                    .accessibilityLabel("Timer name")
            }

            field("Focus") {
                HStack(spacing: 6) {
                    ForEach(Self.focusChoices, id: \.self) { minutes in
                        Button("\(minutes) min") {
                            focus = minutes
                            isCustom = false
                        }
                        .buttonStyle(PomodoroChoiceStyle(isOn: !isCustom && focus == minutes))
                    }
                    Button("Custom") { isCustom = true }
                        .buttonStyle(PomodoroChoiceStyle(isOn: isCustom))
                    if isCustom {
                        TextField("min", text: $customMinutes)
                            .textFieldStyle(.plain)
                            .font(.schemaMeta)
                            .multilineTextAlignment(.center)
                            .frame(width: 44, height: 30)
                            .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.lineStrong, lineWidth: 1))
                            .accessibilityLabel("Focus minutes")
                    }
                }
            }

            field("Break") {
                HStack(spacing: 6) {
                    ForEach(Self.breakChoices, id: \.self) { minutes in
                        Button(minutes == 0 ? "None" : "\(minutes) min") { rest = minutes }
                            .buttonStyle(PomodoroChoiceStyle(isOn: rest == minutes))
                    }
                }
            }

            field("Count toward") {
                SchemaMenuButton("Count toward", matchesWidth: true) {
                    SchemaMenuItem.action("Nothing", isChecked: pageID == nil) { pageID = nil }
                    SchemaMenuItem.divider
                    for page in pages {
                        SchemaMenuItem.action(page.title, isChecked: pageID == page.id) { pageID = page.id }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                        Text(pages.first { $0.id == pageID }?.title ?? "A page (optional)")
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.schemaControl)
                    .foregroundStyle(pageID == nil ? SchemaTheme.inkMuted : SchemaTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
                    .contentShape(Capsule())
                }
            }

            Toggle(isOn: $automatic) {
                Text("Start breaks and the next session by themselves")
                    .font(.schemaControl)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(SchemaTheme.ink)

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.schema(.ghost))
                    .keyboardShortcut(.cancelAction)
                Button {
                    onStart(Choice(name: name, focusMinutes: focusMinutes, breakMinutes: rest, automatic: automatic, pageID: pageID))
                } label: {
                    HStack(spacing: 8) {
                        Text("Start")
                        Text("↩").font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2)).opacity(0.7)
                    }
                }
                .buttonStyle(.schema(.primary))
                .keyboardShortcut(.defaultAction)
                .disabled(focusMinutes < 1)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(SchemaTheme.surface)
        .onAppear { isNameFocused = true }
    }

    private var focusMinutes: Int {
        isCustom ? min(240, Int(customMinutes.trimmingCharacters(in: .whitespaces)) ?? 0) : focus
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.schemaLabel)
                .tracking(0.88)
                .foregroundStyle(SchemaTheme.inkMuted)
            content()
        }
    }
}

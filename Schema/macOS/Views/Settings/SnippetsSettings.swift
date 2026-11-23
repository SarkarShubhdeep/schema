//
//  SnippetsSettings.swift
//  Schema
//
//  Snippets in Settings › Editor (#101, Snippets board): the list, with ⋯
//  for Edit, Duplicate and Delete, and the New snippet sheet.
//

import SwiftUI

struct SnippetsSettings: View {
    /// "Snippets", or "Editor › Snippets" in search results.
    let title: String

    @AppStorage(SchemaPreferences.snippetsKey, store: SchemaPreferences.defaults) private var snippetsJSON = "[]"
    @State private var editing: SnippetDraft?

    private var snippets: [Snippet] { SnippetStore.decode(snippetsJSON) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.schemaLabel)
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    editing = SnippetDraft()
                } label: {
                    Label("New snippet", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(SettingsPillButtonStyle())
                .help("New snippet")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if snippets.isEmpty {
                    Text("Type a trigger anywhere you write and it turns into its text. Start triggers with ; so they don't fire inside words, like ;email.")
                        .font(.satoshi(13, relativeTo: .callout))
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                    row(snippet)
                        .overlay(alignment: .top) {
                            if index > 0 { Rectangle().fill(SchemaTheme.line).frame(height: 1) }
                        }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SchemaTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
        }
        #if DEBUG
        .onAppear {
            if DemoData.isEnabled, DemoData.opensNewSnippet {
                var draft = SnippetDraft()
                draft.trigger = ";standup"
                draft.text = "## Standup {date}\n- [ ] Yesterday\n- [ ] Today\n- [ ] Blockers\n{cursor}"
                editing = draft
            }
        }
        #endif
        .sheet(item: $editing) { draft in
            SnippetSheet(draft: draft, others: snippets.filter { $0.id != draft.id }) { saved in
                save(saved)
                editing = nil
            } onCancel: {
                editing = nil
            }
        }
    }

    private func row(_ snippet: Snippet) -> some View {
        HStack(spacing: 12) {
            Text(snippet.trigger)
                .font(.spaceGrotesk(12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(SchemaTheme.ink)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(minWidth: 64, minHeight: 24, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SchemaTheme.canvas))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
            Text(snippet.preview)
                .font(.satoshi(13, relativeTo: .callout))
                .foregroundStyle(SchemaTheme.inkMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            SchemaMenuButton("Options for \(snippet.trigger)") {
                SchemaMenuItem.action("Edit") { editing = SnippetDraft(snippet) }
                SchemaMenuItem.action("Duplicate") { duplicate(snippet) }
                SchemaMenuItem.divider
                SchemaMenuItem.action("Delete", isDestructive: true) { delete(snippet) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .fixedSize()
            .help("Edit, duplicate or delete")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { editing = SnippetDraft(snippet) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snippet.trigger), \(snippet.preview)")
        .accessibilityAction(named: "Edit") { editing = SnippetDraft(snippet) }
    }

    private func save(_ snippet: Snippet) {
        var list = snippets
        if let index = list.firstIndex(where: { $0.id == snippet.id }) {
            list[index] = snippet
        } else {
            list.append(snippet)
        }
        snippetsJSON = SnippetStore.encode(list)
    }

    private func duplicate(_ snippet: Snippet) {
        var trigger = snippet.trigger + "2"
        var n = 2
        while snippets.contains(where: { $0.trigger == trigger }) {
            n += 1
            trigger = snippet.trigger + "\(n)"
        }
        var list = snippets
        let index = list.firstIndex(where: { $0.id == snippet.id }).map { $0 + 1 } ?? list.count
        list.insert(Snippet(trigger: trigger, text: snippet.text), at: index)
        snippetsJSON = SnippetStore.encode(list)
    }

    private func delete(_ snippet: Snippet) {
        snippetsJSON = SnippetStore.encode(snippets.filter { $0.id != snippet.id })
    }
}

/// A snippet being made or edited.
struct SnippetDraft: Identifiable {
    var id = UUID()
    var trigger = ";"
    var text = ""
    var isNew = true

    init() {}

    init(_ snippet: Snippet) {
        id = snippet.id
        trigger = snippet.trigger
        text = snippet.text
        isNew = false
    }
}

/// New snippet, or Edit snippet (Snippets board, dark half).
private struct SnippetSheet: View {
    @State var draft: SnippetDraft
    let others: [Snippet]
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    @FocusState private var focus: Field?
    private enum Field { case trigger, text }

    private var problem: SnippetRules.Problem? {
        SnippetRules.problem(trigger: draft.trigger, text: draft.text, others: others)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.isNew ? "New snippet" : "Edit snippet")
                .font(.spaceGrotesk(20, weight: .semibold, relativeTo: .title2))
                .foregroundStyle(SchemaTheme.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("Trigger")
                    .font(.schemaControl)
                    .foregroundStyle(SchemaTheme.ink)
                TextField("Trigger", text: $draft.trigger, prompt: Text(";email"))
                    .textFieldStyle(.plain)
                    .font(.spaceGrotesk(14, weight: .medium, relativeTo: .body))
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Capsule(style: .continuous).fill(SchemaTheme.canvas))
                    .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.lineStrong, lineWidth: 1))
                    .focused($focus, equals: .trigger)
                    .accessibilityLabel("Trigger")
                Text(triggerHint)
                    .font(.schemaCaption)
                    .foregroundStyle(triggerProblem == nil ? SchemaTheme.inkMuted : SchemaTheme.danger)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Text")
                    .font(.schemaControl)
                    .foregroundStyle(SchemaTheme.ink)
                TextEditor(text: $draft.text)
                    .font(.satoshi(14, relativeTo: .body))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 120)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SchemaTheme.canvas))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SchemaTheme.lineStrong, lineWidth: 1))
                    .focused($focus, equals: .text)
                    .accessibilityLabel("Text")
                HStack(spacing: 6) {
                    Text("Insert")
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkMuted)
                    token("{date}", help: "Today's date when the snippet is used")
                    token("{time}", help: "The time when the snippet is used")
                    token("{cursor}", help: "Where the caret lands afterwards")
                }
                Text("Markdown works: lines starting with - [ ] become to-dos, # makes a heading.")
                    .font(.schemaCaption)
                    .foregroundStyle(SchemaTheme.inkMuted)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(SettingsPillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "Save snippet" : "Save") {
                    onSave(Snippet(id: draft.id, trigger: draft.trigger, text: draft.text))
                }
                .buttonStyle(SnippetPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(SchemaTheme.surface)
        .onAppear { focus = draft.isNew ? .trigger : .text }
    }

    private var triggerProblem: SnippetRules.Problem? {
        guard let problem, problem != .noText else { return nil }
        return problem
    }

    private var triggerHint: String {
        if let triggerProblem { return triggerProblem.message }
        return SnippetRules.startsWithSymbol(draft.trigger)
            ? "It turns into the text as soon as you finish typing it."
            : "Plain words only fire on their own. Start with ; to fire anywhere."
    }

    private func token(_ text: String, help: String) -> some View {
        Button(text) {
            draft.text += text
            focus = .text
        }
        .buttonStyle(SnippetTokenButtonStyle())
        .help(help)
    }
}

private struct SnippetTokenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.spaceGrotesk(12, weight: .medium, relativeTo: .caption))
            .foregroundStyle(SchemaTheme.ink)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(configuration.isPressed ? SchemaTheme.surfaceHover : .clear))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
    }
}

/// The one yellow button in the sheet.
private struct SnippetPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.satoshi(13, weight: .semibold, relativeTo: .callout))
            .foregroundStyle(SchemaTheme.onAccent)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Capsule(style: .continuous).fill(SchemaTheme.accent.opacity(configuration.isPressed ? 0.85 : 1)))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
    }
}

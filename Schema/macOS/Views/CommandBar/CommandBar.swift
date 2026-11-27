//
//  CommandBar.swift
//  Schema
//
//  ⌘K (or ⌘⇧P): one field that finds pages, tasks, lines inside pages and
//  commands (#122). ↑↓ move, Return opens, Esc closes, > lists commands.
//

import SwiftUI

struct CommandBar: View {
    let search: CommandSearch
    var initialQuery = ""
    let onPerform: (CommandBarAction) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let results = search.results(for: query)
        ZStack(alignment: .top) {
            SchemaTheme.ink.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: ShellMetrics.innerGap) {
                field(results: results)
                if results.isEmpty {
                    Text("Nothing matches “\(query)”.")
                        .font(.schemaBody)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                } else {
                    resultList(results)
                }
                footer
            }
            .frame(width: 640)
            .shellIsland()
            .shadow(color: .black.opacity(0.24), radius: 32, y: 24)
            .padding(.top, 96)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Search everything")
        }
        .onAppear {
            isFieldFocused = true
            query = initialQuery
            #if DEBUG
            if DemoData.isEnabled, let demo = DemoData.commandBarQuery { query = demo }
            #endif
        }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    // MARK: Field

    private func field(results: [CommandBarResult]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SchemaTheme.inkMuted)
            TextField("Search pages, tasks and lines, or type > for commands", text: $query)
                .textFieldStyle(.plain)
                .font(.satoshi(17, relativeTo: .title3))
                .foregroundStyle(SchemaTheme.ink)
                .focused($isFieldFocused)
                .onSubmit { open(results, at: selection) }
                .onKeyPress(.downArrow) { move(1, in: results); return .handled }
                .onKeyPress(.upArrow) { move(-1, in: results); return .handled }
                .onKeyPress(.escape) { onClose(); return .handled }
                .onExitCommand(perform: onClose)
                .accessibilityLabel("Search everything")
            KeyHint("esc")
        }
        .padding(.horizontal, 12)
        .frame(height: ShellMetrics.control)
        .background(
            RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous)
                .fill(SchemaTheme.surface)
        )
    }

    // MARK: Results

    private func resultList(_ results: [CommandBarResult]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        if index == 0 || results[index - 1].group != result.group {
                            SchemaSectionLabel(result.group.rawValue)
                                .padding(.horizontal, 12)
                                .padding(.top, index == 0 ? 4 : 10)
                                .padding(.bottom, 4)
                        }
                        CommandBarRow(result: result, isSelected: index == selection) {
                            open(results, at: index)
                        }
                        .id(index)
                        .onHover { if $0 { selection = index } }
                    }
                }
                .padding(.bottom, 4)
                .themedScrollBars()
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: 420)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selection) { _, index in
                proxy.scrollTo(index)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            hint("↑↓", "move")
            hint("↩", "open")
            hint(">", "commands")
            Spacer()
            hint("esc", "close")
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private func hint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            KeyHint(keys)
            Text(label)
                .font(.schemaCaption)
                .foregroundStyle(SchemaTheme.inkMuted)
        }
    }

    // MARK: Actions

    private func move(_ offset: Int, in results: [CommandBarResult]) {
        guard !results.isEmpty else { return }
        selection = (selection + offset + results.count) % results.count
    }

    private func open(_ results: [CommandBarResult], at index: Int) {
        guard results.indices.contains(index) else { return }
        onClose()
        onPerform(results[index].action)
    }
}

private struct CommandBarRow: View {
    let result: CommandBarResult
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: result.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .frame(width: 18)
                Text(result.title)
                    .font(.schemaBody)
                    .foregroundStyle(SchemaTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if !result.detail.isEmpty {
                    Text(result.detail)
                        .font(.schemaCaption)
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .lineLimit(1)
                        .fixedSize()
                }
                if !result.keys.isEmpty {
                    KeyHint(result.keys)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous)
                    .fill(isSelected ? SchemaTheme.islandCard : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: ShellMetrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(result.detail.isEmpty ? result.title : "\(result.title), \(result.detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small outlined key, like ⌘K.
struct KeyHint: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
            .foregroundStyle(SchemaTheme.inkMuted)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(SchemaTheme.line, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

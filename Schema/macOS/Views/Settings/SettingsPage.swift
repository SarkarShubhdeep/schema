//
//  SettingsPage.swift
//  Schema
//
//  Settings as its own page (#108, Settings boards on the canvas): a section
//  of grouped cards, or what a search found across every section. Each row
//  has a title and a line of description on the left and its control on the
//  right. Every setting from the old Settings sheet is here, unchanged.
//

import SwiftUI

struct SettingsPage: View {
    @Environment(WorkspaceState.self) private var workspace
    @Bindable var listViewModel: ListViewModel
    let lists: [SchemaList]
    let notificationService: any NotificationServiceProtocol

    @State private var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    @State private var isRequestingAuthorization = false
    @State private var quickNotePageID = SchemaPreferences.quickNotePageID
    @AppStorage(SchemaPreferences.replacesAsYouTypeKey, store: SchemaPreferences.defaults) private var replacesAsYouType = true

    private var query: String { workspace.settingsQuery.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let results = query.isEmpty ? SettingsCatalog.groups(in: workspace.settingsSection) : SettingsCatalog.search(query)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(found: results.reduce(0) { $0 + $1.entries.count })

                ForEach(results) { group in
                    card(group, showsSection: !query.isEmpty)
                }

                if results.isEmpty {
                    Text(query.isEmpty ? "Settings for GitHub arrive with the GitHub inbox." : "No settings match “\(query)”.")
                        .font(.schemaBody)
                        .foregroundStyle(SchemaTheme.inkMuted)
                }
            }
            .frame(maxWidth: ShellMetrics.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 56)
        }
        .scrollIndicators(.automatic)
        .task {
            authorizationStatus = await notificationService.authorizationStatus()
        }
    }

    // MARK: Header

    private func header(found: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(query.isEmpty ? "Settings" : "Settings · \(found) found")
                .font(.schemaControl)
                .foregroundStyle(SchemaTheme.inkMuted)
            Text(query.isEmpty ? workspace.settingsSection.title : "Results for “\(query)”")
                .font(.spaceGrotesk(40, weight: .semibold, relativeTo: .largeTitle))
                .tracking(-1.2)
                .foregroundStyle(SchemaTheme.ink)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: Cards and rows

    @ViewBuilder
    private func card(_ group: SettingsResultGroup, showsSection: Bool) -> some View {
        if group.entries.contains(where: { $0.key == .snippets }) {
            SnippetsSettings(title: showsSection ? group.title : group.group)
        } else {
            plainCard(group, showsSection: showsSection)
        }
    }

    private func plainCard(_ group: SettingsResultGroup, showsSection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(showsSection ? group.title : group.group)
                .font(.schemaLabel)
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(SchemaTheme.inkMuted)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                    row(entry)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                Rectangle().fill(SchemaTheme.line).frame(height: 1)
                            }
                        }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SchemaTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
        }
    }

    private func row(_ entry: SettingsEntry) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title(entry))
                    .font(.satoshi(15, weight: .medium, relativeTo: .body))
                    .foregroundStyle(SchemaTheme.ink)
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.satoshi(13, relativeTo: .callout))
                        .foregroundStyle(SchemaTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            control(for: entry)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }

    /// The title, with what was searched for marked.
    private func title(_ entry: SettingsEntry) -> AttributedString {
        var text = AttributedString(entry.title)
        if let range = SettingsCatalog.highlight(in: entry.title, for: query),
           let lower = AttributedString.Index(range.lowerBound, within: text),
           let upper = AttributedString.Index(range.upperBound, within: text) {
            text[lower..<upper].backgroundColor = SchemaTheme.lineStrong.opacity(0.35)
        }
        return text
    }

    @ViewBuilder
    private func control(for entry: SettingsEntry) -> some View {
        @Bindable var workspace = workspace
        switch entry.key {
        case .defaultList:
            SchemaMenuPicker(
                title: entry.title,
                selection: defaultListBinding,
                options: writableLists.map { (value: Optional($0.id), label: $0.title) }
            )
            .fixedSize()
        case .weekStart:
            SettingsSegmented(title: entry.title, selection: $workspace.weekStart, options: WeekStart.allCases.map { ($0, $0.label) })
        case .replaceAsYouType:
            settingsSwitch(entry.title, isOn: $replacesAsYouType)
        case .snippets:
            EmptyView()
        case .quickNotePage:
            SchemaMenuPicker(
                title: entry.title,
                selection: quickNotePageBinding,
                options: scratchpads.isEmpty
                    ? [(value: UUID?.none, label: "Ideas (made on first note)")]
                    : scratchpads.map { (value: Optional($0.id), label: $0.title) }
            )
            .fixedSize()
        case .quickNoteShortcut:
            value("⌃⌥N")
        case .followerRoutines:
            settingsSwitch(entry.title, isOn: $workspace.allowIndependentFollowerRoutineCompletion)
        case .notificationPermission:
            if authorizationStatus == .authorized {
                value("Allowed")
            } else {
                HStack(spacing: 10) {
                    value(authorizationStatus == .denied ? "Off" : "Not asked yet")
                    if authorizationStatus == .notDetermined {
                        Button("Allow", action: requestAuthorization)
                            .buttonStyle(SettingsPillButtonStyle())
                            .disabled(isRequestingAuthorization)
                    }
                }
            }
        case .version:
            value(versionLabel)
        }
    }

    private func settingsSwitch(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.switch)
            .tint(SchemaTheme.ink)
            .labelsHidden()
            .accessibilityLabel(title)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.schemaMeta)
            .foregroundStyle(SchemaTheme.inkMuted)
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: Values

    private var writableLists: [SchemaList] { lists.filter(\.acceptsTasks) }
    private var scratchpads: [SchemaList] { lists.filter(\.isScratchpad) }

    private var defaultListBinding: Binding<UUID?> {
        Binding(
            get: { listViewModel.defaultWritableListID ?? writableLists.first?.id },
            set: { listViewModel.defaultWritableListID = $0 }
        )
    }

    private var quickNotePageBinding: Binding<UUID?> {
        Binding(
            get: { QuickNoteStore.targetPage(in: lists, preferredID: quickNotePageID)?.id },
            set: {
                quickNotePageID = $0
                SchemaPreferences.quickNotePageID = $0
            }
        )
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func requestAuthorization() {
        isRequestingAuthorization = true
        Task {
            defer { isRequestingAuthorization = false }
            _ = try? await notificationService.requestAuthorization()
            authorizationStatus = await notificationService.authorizationStatus()
        }
    }
}

/// Two or three choices in a capsule, the chosen one raised (Settings boards).
struct SettingsSegmented<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option in
                let isOn = option.0 == selection
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.schemaControl)
                        .foregroundStyle(isOn ? SchemaTheme.ink : SchemaTheme.inkMuted)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isOn ? SchemaTheme.surface : .clear)
                                .shadow(color: .black.opacity(isOn ? 0.12 : 0), radius: 1, y: 1)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Capsule(style: .continuous).fill(SchemaTheme.surfaceHover))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// A small outlined pill, for a one-off action inside a settings row.
struct SettingsPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.satoshi(12, weight: .medium, relativeTo: .caption))
            .foregroundStyle(SchemaTheme.ink)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(configuration.isPressed ? SchemaTheme.surfaceHover : .clear))
            .overlay(Capsule(style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
            .contentShape(Capsule())
    }
}

//
//  SettingsSidebar.swift
//  Schema
//
//  The sidebar while Settings is open (#108): Back to Schema, the search
//  field and one row per section, in place of the app's sidebar.
//

import SwiftUI

struct SettingsSidebar: View {
    @Environment(WorkspaceState.self) private var workspace
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        @Bindable var workspace = workspace
        let searching = !workspace.settingsQuery.trimmingCharacters(in: .whitespaces).isEmpty

        VStack(alignment: .leading, spacing: 2) {
            // The window controls sit here (WindowControlsPlacement, #116).
            Color.clear
                .frame(height: ShellMetrics.control)
                .padding(.bottom, ShellMetrics.innerGap - 2)
                .accessibilityHidden(true)

            Button {
                workspace.showSettings = false
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Back to Schema")
                }
                .font(.schemaControl)
                .foregroundStyle(SchemaTheme.inkMuted)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to Schema  Esc")

            Text("Settings")
                .font(.spaceGrotesk(19, weight: .bold, relativeTo: .title3))
                .tracking(-0.4)
                .foregroundStyle(SchemaTheme.ink)
                .padding(.leading, 12)
                .frame(height: SidebarMetrics.rowHeight)
                .accessibilityAddTraits(.isHeader)

            searchField(query: $workspace.settingsQuery, isActive: searching)
                .padding(.bottom, 10)

            ForEach(SettingsSection.allCases) { section in
                SidebarRow(
                    title: section.title,
                    isActive: !searching && workspace.settingsSection == section,
                    trailing: section.comingIn.map { .text($0) } ?? .none,
                    tooltip: section.comingIn.map { "\(section.title) arrives in \($0)" } ?? section.title
                ) {
                    Image(systemName: section.systemImage)
                } action: {
                    workspace.settingsQuery = ""
                    workspace.settingsSection = section
                }
                .disabled(section.comingIn != nil)
            }
        }
        .frame(width: ShellMetrics.sidebarWidth - ShellMetrics.islandPadding * 2, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .shellIsland()
    }

    private func searchField(query: Binding<String>, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SchemaTheme.inkMuted)
            TextField("Search settings", text: query)
                .textFieldStyle(.plain)
                .font(.schemaControl)
                .foregroundStyle(SchemaTheme.ink)
                .focused($isSearchFocused)
                .accessibilityLabel("Search settings")
            if isActive {
                Button {
                    query.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(SchemaTheme.inkFaint)
                }
                .buttonStyle(.plain)
                .help("Clear search  Esc")
                .accessibilityLabel("Clear search")
            } else {
                Text("⌘F")
                    .font(.spaceGrotesk(11, weight: .medium, relativeTo: .caption2))
                    .foregroundStyle(SchemaTheme.inkMuted)
                    .padding(.horizontal, 6)
                    .frame(minHeight: 20)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SchemaTheme.line, lineWidth: 1))
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 36)
        .background(Capsule(style: .continuous).fill(SchemaTheme.surface))
        .overlay(Capsule(style: .continuous).strokeBorder(isActive || isSearchFocused ? SchemaTheme.lineStrong : SchemaTheme.line, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture { isSearchFocused = true }
    }
}

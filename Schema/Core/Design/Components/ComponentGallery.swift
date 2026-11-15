//
//  ComponentGallery.swift
//  Schema
//
//  DEBUG only. Every shared component on one screen, for review and PR
//  screenshots. Launch with `-SchemaComponentGallery` (add `-SchemaDemoDark`
//  for dark mode).
//

#if DEBUG
import SwiftUI

enum ComponentGallery {
    static let isEnabled = CommandLine.arguments.contains("-SchemaComponentGallery")
}

struct ComponentGalleryView: View {
    @State private var checks = [false, true, false]
    @State private var progress = 0.6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Components")
                    .font(.schemaDisplay)
                    .foregroundStyle(SchemaTheme.ink)

                section("Buttons") {
                    HStack(spacing: 10) {
                        Button("Create list") {}.buttonStyle(.schema(.primary))
                        Button("Sort") {}.buttonStyle(.schema(.secondary))
                        Button("Cancel") {}.buttonStyle(.schema(.ghost))
                        Button("Delete") {}.buttonStyle(.schema(.danger))
                        Button("Done") {}.buttonStyle(.schema(.ink))
                    }
                    HStack(spacing: 10) {
                        Button("Small primary") {}.buttonStyle(.schema(.primary, size: .small))
                        Button("Small") {}.buttonStyle(.schema(.secondary, size: .small))
                        Button("Disabled") {}.buttonStyle(.schema(.primary)).disabled(true)
                    }
                    HStack(spacing: 8) {
                        SchemaIconButton(systemImage: "magnifyingglass", label: "Search", shortcut: "⌘K") {}
                        SchemaIconButton(systemImage: "gearshape", label: "Settings", shortcut: "⌘,") {}
                        SchemaIconButton(systemImage: "plus", label: "New page", isFilled: true) {}
                    }
                }

                section("Checkboxes") {
                    HStack(spacing: 24) {
                        checkbox(0, "Open")
                        checkbox(1, "Done")
                        HStack(spacing: 6) {
                            SchemaCheckbox(isChecked: false, isBlocked: true, label: "Blocked") {}
                            Text("Blocked").font(.schemaTask).foregroundStyle(SchemaTheme.inkMuted)
                        }
                    }
                }

                section("Labels") {
                    HStack(spacing: 8) {
                        SchemaChip(text: "Errands")
                        SchemaChip(text: "Needs reply", style: .outline)
                        SchemaChip(text: "Today", systemImage: "calendar")
                        SchemaBadge(count: 12)
                        SchemaBadge(count: 3, isProminent: true)
                        SchemaKeyHint("N")
                        SchemaKeyHint("⌃⌥N")
                    }
                }

                section("Card and progress") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Today").font(.schemaTitle).foregroundStyle(SchemaTheme.ink)
                            Spacer()
                            Text("3 of 5").font(.schemaMeta).foregroundStyle(SchemaTheme.inkMuted)
                        }
                        SchemaProgressBar(value: progress, accessibilityText: "Today's progress")
                    }
                    .schemaCard()
                    .frame(maxWidth: 360)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SchemaTheme.canvas)
        .font(.schemaBody)
        .frame(minWidth: 720, minHeight: 560)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SchemaSectionLabel(title)
            content()
        }
    }

    private func checkbox(_ index: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            SchemaCheckbox(isChecked: checks[index], label: title) { checks[index].toggle() }
            Text(title).font(.schemaTask).foregroundStyle(SchemaTheme.ink)
        }
    }
}

#Preview { ComponentGalleryView() }
#endif

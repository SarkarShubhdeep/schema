//
//  ListPreferencesMenu.swift
//  Schema
//

import SwiftUI

struct ListPreferencesMenu: View {
    @Bindable var listViewModel: ListViewModel
    let requiresManualSort: Bool

    var body: some View {
        Menu {
            Menu("Sort") {
                ForEach(TaskSortOption.allCases) { option in
                    Button {
                        withAnimation(SchemaMotion.smooth) {
                            listViewModel.sortOption = option
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            if listViewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(requiresManualSort && option != .manual)
                }
            }

            Menu("Filter") {
                ForEach(TaskFilterOption.allCases) { option in
                    Button {
                        withAnimation(SchemaMotion.smooth) {
                            listViewModel.filterOption = option
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                            if listViewModel.filterOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(SchemaTheme.surface))
                .overlay(Circle().strokeBorder(SchemaTheme.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Page options")
        .accessibilityLabel("Page options")
    }
}

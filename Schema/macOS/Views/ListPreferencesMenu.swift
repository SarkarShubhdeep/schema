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
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .medium))
                Text("List Preferences")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(SchemaTheme.mutedText)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

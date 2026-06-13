//
//  ListContextBar.swift
//  Schema
//

import SwiftUI

struct ListContextBar: View {
    let onAllLists: () -> Void
    @Bindable var listViewModel: ListViewModel

    var body: some View {
        HStack {
            Button(action: onAllLists) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("All Lists")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(SchemaTheme.mutedText)
            }
            .buttonStyle(.plain)

            Spacer()

            ListPreferencesMenu(listViewModel: listViewModel)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(SchemaTheme.background)
    }
}

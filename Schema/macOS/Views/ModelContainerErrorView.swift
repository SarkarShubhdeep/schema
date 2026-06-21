//
//  ModelContainerErrorView.swift
//  Schema
//

import SwiftUI

struct ModelContainerErrorView: View {
    let error: ModelContainerError
    let onRetry: () -> Void
    let onResetStore: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(SchemaTheme.mutedText)

            Text("Schema couldn't open your data")
                .font(.title2.weight(.semibold))

            Text(error.message)
                .font(.system(size: 13))
                .foregroundStyle(SchemaTheme.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Text("Your tasks are stored locally. You can retry opening the store or reset it and start fresh.")
                .font(.system(size: 12))
                .foregroundStyle(SchemaTheme.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button("Retry") {
                    onRetry()
                }
                .keyboardShortcut(.defaultAction)

                Button("Reset Data…", role: .destructive) {
                    onResetStore()
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SchemaTheme.background)
    }
}

//
//  QuickEntryField.swift
//  Schema
//

import SwiftUI

struct QuickEntryField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    var focusBinding: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SchemaTheme.accent)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused(focusBinding)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SchemaTheme.surface)
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SchemaTheme.divider, lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(SchemaTheme.background)
    }
}

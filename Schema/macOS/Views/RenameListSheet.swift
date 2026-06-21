//
//  RenameListSheet.swift
//  Schema
//

import SwiftUI

struct RenameListSheet: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename List")
                .font(.title2.weight(.semibold))

            TextField("List name", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveIfValid)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save", action: saveIfValid)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func saveIfValid() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSave()
    }
}

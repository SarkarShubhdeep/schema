//
//  NewListSheet.swift
//  Schema
//

import SwiftUI

struct NewListSheet: View {
    @Binding var title: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New List")
                .font(.title2.weight(.semibold))

            TextField("List name", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCreate)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create", action: onCreate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

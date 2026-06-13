//
//  AddTaskBar.swift
//  Schema
//

import SwiftUI

struct AddTaskBar: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    var focusBinding: FocusState<Bool>.Binding

    private enum Metrics {
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 10
        static let contentHeight: CGFloat = 22
        static var controlHeight: CGFloat {
            contentHeight + (verticalPadding * 2)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if isExpanded {
                expandedField
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                addTaskButton
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(SchemaTheme.background)
        .animation(SchemaMotion.fast, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                DispatchQueue.main.async {
                    focusBinding.wrappedValue = true
                }
            }
        }
    }

    private var addTaskButton: some View {
        Button(action: openAddTask) {
            addTaskContainer(showFocusBorder: false) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SchemaTheme.mutedText)

                Text("Add task")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SchemaTheme.mutedText)

                shortcutBadge
            }
        }
        .buttonStyle(.plain)
    }

    private var expandedField: some View {
        addTaskContainer(showFocusBorder: true) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.mutedText)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .frame(height: Metrics.contentHeight)
                .focused(focusBinding)
                .onSubmit(onSubmit)
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
        }
    }

    private func addTaskContainer<Content: View>(
        showFocusBorder: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .frame(height: Metrics.controlHeight, alignment: .leading)
        .padding(.horizontal, Metrics.horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    showFocusBorder ? SchemaTheme.accent.opacity(0.45) : .clear,
                    lineWidth: 1.5
                )
        )
    }

    private var shortcutBadge: some View {
        Text("n")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(SchemaTheme.mutedText)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(SchemaTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(SchemaTheme.divider, lineWidth: 1)
                    )
            )
    }

    private func openAddTask() {
        isExpanded = true
    }
}

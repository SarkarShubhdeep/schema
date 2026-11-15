//
//  DetailsPanelView.swift
//  Schema
//
//  Right column of the window. It scrolls on its own; the day overview and
//  task details move in with later issues, so for now it shows a quiet
//  empty state.
//

import SwiftUI

struct DetailsPanelView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SchemaSectionLabel("Details")
                Text("Select a task to see its details here.")
                    .font(.schemaCaption)
                    .foregroundStyle(SchemaTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
        .frame(width: ShellMetrics.detailsWidth)
        .frame(maxHeight: .infinity)
        .background(SchemaTheme.canvas.ignoresSafeArea())
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SchemaTheme.line)
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }
}

//
//  SchemaToolbar.swift
//  Schema
//

import SwiftUI

extension View {
    func schemaWindowToolbar() -> some View {
        self
            .navigationTitle("Schema")
            .toolbarBackground(SchemaTheme.background, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }
}

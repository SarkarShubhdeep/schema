//
//  ScratchpadPageView.swift
//  Schema
//
//  A scratchpad page in the main column. For now only the header and an
//  empty page; the block editor comes in #38.
//

import SwiftUI

struct ScratchpadPageView: View {
    let page: SchemaList

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 6) {
                    Text("Pages")
                    Text("/").foregroundStyle(SchemaTheme.inkFaint)
                    Text(page.title).lineLimit(1)
                }
                .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                .foregroundStyle(SchemaTheme.inkMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Scratchpad", systemImage: PageKind.scratchpad.systemImage)
                        .font(.satoshi(13, weight: .medium, relativeTo: .callout))
                        .foregroundStyle(SchemaTheme.inkMuted)
                    Text(page.title)
                        .font(.spaceGrotesk(44, weight: .semibold, relativeTo: .largeTitle))
                        .foregroundStyle(SchemaTheme.ink)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                }

                Text("This page is empty. Writing in scratchpads arrives in the next update.")
                    .font(.satoshi(15, relativeTo: .body))
                    .foregroundStyle(SchemaTheme.inkMuted)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 56)
        }
    }
}

extension PageKind {
    var displayName: String {
        switch self {
        case .todo: "To-do list"
        case .scratchpad: "Scratchpad"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "checklist"
        case .scratchpad: "doc.text"
        }
    }
}

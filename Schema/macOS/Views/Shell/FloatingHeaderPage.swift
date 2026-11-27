//
//  FloatingHeaderPage.swift
//  Schema
//
//  A page whose content runs the full height of the window (#133): it
//  scrolls up behind the header island, where a progressive blur lets it
//  fade out, and down behind the selection bar to the window's bottom edge.
//

import SwiftUI

extension EnvironmentValues {
    /// Room a scrolling page leaves above and below its content so the
    /// first and last rows can clear the header island and the selection bar.
    @Entry var pageContentInsets = EdgeInsets()
}

struct FloatingHeaderPage<Header: View, Content: View>: View {
    /// False for pages whose own scrolling sits lower down (the editor
    /// pages), so the blur doesn't cover their title.
    var fadesContent = true
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.pageContentInsets, FloatingHeaderPageMetrics.contentInsets)
            .overlay(alignment: .top) {
                if fadesContent {
                    ProgressiveBlurEdge()
                        .frame(height: FloatingHeaderPageMetrics.headerClearance + 28)
                }
            }
            .overlay(alignment: .top) {
                header()
                    .padding(.top, ShellMetrics.margin)
            }
            // Out past the shell's margin to the window's edges.
            .padding(.vertical, -ShellMetrics.margin)
    }
}

enum FloatingHeaderPageMetrics {
    /// From the window's top edge to just below the header island.
    static let headerClearance = ShellMetrics.margin + ShellMetrics.headerHeight
    /// Room for the selection bar and the gap under it.
    static let selectionBarClearance: CGFloat = 72
    /// What a page that scrolls under the header leaves above and below
    /// its content, measured from the window's edges.
    static let contentInsets = EdgeInsets(
        top: headerClearance + ShellMetrics.margin,
        leading: 0,
        bottom: ShellMetrics.margin + selectionBarClearance,
        trailing: 0
    )
}

/// A blur that is strongest at the top edge and fades to nothing at the
/// bottom: a few layers of material, each masked a little shorter, under a
/// wash of the canvas color.
struct ProgressiveBlurEdge: View {
    var body: some View {
        ZStack {
            ForEach([0.9, 0.65, 0.4], id: \.self) { reach in
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: reach * 0.45),
                                .init(color: .clear, location: reach),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
            LinearGradient(
                stops: [
                    .init(color: SchemaTheme.canvas, location: 0),
                    .init(color: SchemaTheme.canvas.opacity(0.9), location: 0.35),
                    .init(color: SchemaTheme.canvas.opacity(0.6), location: 0.7),
                    .init(color: SchemaTheme.canvas.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

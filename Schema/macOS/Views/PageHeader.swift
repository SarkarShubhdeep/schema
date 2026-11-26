//
//  PageHeader.swift
//  Schema
//
//  The top of a to-do page: the header island (PageHeaderBar: breadcrumb,
//  sort pills, page options), then in the page the page type, a large title
//  (double-click a page title to rename it), the open count, and
//  done-of-total with a flat progress bar.
//

import SwiftUI

struct PageHeaderModel {
    /// "Pages" or "Views".
    let crumb: String
    let title: String
    let kindLabel: String
    let kindSystemImage: String
    let openCount: Int
    let doneCount: Int
    /// The page to rename on double-click; `nil` for Everything and smart views.
    let renamableList: SchemaList?
    /// Today shows progress in its tiles instead.
    var showsProgress = true
}

struct PageHeader: View {
    @Environment(WorkspaceState.self) private var workspace

    let model: PageHeaderModel
    @Bindable var listViewModel: ListViewModel
    let requiresManualSort: Bool
    let onRename: (SchemaList, String) -> Void
    @Binding var isEditingListName: Bool

    /// Set by Rename in a menu; focuses the title with its text selected.
    @State private var titleFocus: BlockFocusRequest?

    private static let titleFont = Font.spaceGrotesk(44, weight: .semibold, relativeTo: .largeTitle)

    var body: some View {
        titleBlock
        // Rename from the page menu or the sidebar (#42).
        .onAppear(perform: takeRenameRequest)
        .onChange(of: workspace.pageRenameRequest) { _, _ in takeRenameRequest() }
    }

    // MARK: Title block

    private var titleBlock: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SchemaChip(text: model.kindLabel.uppercased(), systemImage: model.kindSystemImage)

                titleView

                Text("\(model.openCount) open")
                    .font(.spaceGrotesk(14, weight: .medium, relativeTo: .body))
                    .foregroundStyle(SchemaTheme.ink)
            }

            Spacer(minLength: 0)

            progress
        }
    }

    /// A page's title is editable in place; views (Today, Everything) are not.
    @ViewBuilder
    private var titleView: some View {
        if let list = model.renamableList {
            PageTitleField(
                title: list.title,
                pageID: list.id,
                focusRequest: titleFocus,
                onRename: { onRename(list, $0) },
                onEditingChange: { isEditingListName = $0 }
            )
        } else {
            Text(model.title)
                .font(Self.titleFont)
                .tracking(-1.2)
                .foregroundStyle(SchemaTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var progress: some View {
        let total = model.openCount + model.doneCount
        if total > 0, model.showsProgress {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(model.doneCount)")
                        .font(.spaceGrotesk(28, weight: .medium, relativeTo: .title).monospacedDigit())
                        .foregroundStyle(SchemaTheme.ink)
                    Text(" / \(total) done")
                        .font(.spaceGrotesk(15, weight: .medium, relativeTo: .body).monospacedDigit())
                        .foregroundStyle(SchemaTheme.inkMuted)
                }
                .fixedSize()
                SchemaProgressBar(
                    value: Double(model.doneCount) / Double(total),
                    accessibilityText: "\(model.doneCount) of \(total) tasks done"
                )
                .frame(width: 200)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Rename

    private func takeRenameRequest() {
        guard let id = model.renamableList?.id, workspace.takePageRenameRequest(for: id) else { return }
        titleFocus = BlockFocusRequest(blockID: id, caret: .all)
    }
}

/// The header island of a to-do page or view (#116): where you are, then
/// the sort pills and the page options.
struct PageHeaderBar: View {
    let model: PageHeaderModel
    @Bindable var listViewModel: ListViewModel
    let requiresManualSort: Bool

    var body: some View {
        HeaderIsland {
            Text(model.crumb)
            Text("/")
                .foregroundStyle(SchemaTheme.inkFaint)
            Text(model.title)
                .foregroundStyle(SchemaTheme.ink)
                .truncationMode(.tail)
        } trailing: {
            HStack(spacing: 6) {
                sortPill("Manual", option: .manual)
                sortPill("Due", option: .reminderTime)
                sortPill("A–Z", option: .alphabetical)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sort")

            ListPreferencesMenu(listViewModel: listViewModel, requiresManualSort: requiresManualSort, page: model.renamableList)
        }
    }

    private func sortPill(_ title: String, option: TaskSortOption) -> some View {
        let isOn = listViewModel.sortOption == option
        return Button(title) {
            withAnimation(SchemaMotion.smooth) {
                listViewModel.sortOption = option
            }
        }
        .buttonStyle(SortPillStyle(isOn: isOn))
        .disabled(requiresManualSort && option != .manual)
        .help(requiresManualSort && option != .manual ? "Routine chains keep this page in manual order" : "Sort: \(title)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A sort option: dark pill when chosen, outlined pill otherwise.
private struct SortPillStyle: ButtonStyle {
    let isOn: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.schemaControl)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(isOn ? SchemaTheme.canvas : SchemaTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(isOn ? SchemaTheme.ink : (isHovered ? SchemaTheme.surfaceHover : SchemaTheme.surface))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isOn ? SchemaTheme.ink : SchemaTheme.line, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(SchemaMotion.fast, value: isOn)
            .animation(SchemaMotion.fast, value: isHovered)
            .onHover { isHovered = $0 && isEnabled }
    }
}

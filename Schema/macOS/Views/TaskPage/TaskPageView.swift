//
//  TaskPageView.swift
//  Schema
//
//  A task opened as its own page (#31): breadcrumb back to its list,
//  previous and next, a large checkbox and title, then its body in the
//  TipTap editor (#77). To-do lines here are steps of the task, not new tasks. The
//  task's properties live in the right panel (TaskPagePanel).
//

import SwiftData
import SwiftUI

struct TaskPageActions {
    var onBack: () -> Void
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onToggle: () -> Void
    var onRename: (String) -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void
    var movePages: [SchemaList]
    var onMove: (SchemaList) -> Void
}

struct TaskPageView: View {
    let task: SchemaTask
    /// The page or view the task was opened from, for the breadcrumb.
    let originTitle: String
    let isBlocked: Bool
    let actions: TaskPageActions

    @Environment(\.modelContext) private var modelContext
    @State private var editorFocus: EditorFocusRequest?
    @State private var title = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            topBar
            VStack(alignment: .leading, spacing: 20) {
                header
                Rectangle()
                    .fill(SchemaTheme.line)
                    .frame(height: 1)
                    .padding(.leading, PageBodyEditor.gutterWidth)
            }
            .frame(maxWidth: ShellMetrics.contentWidth + PageBodyEditor.gutterWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            PageBodyEditor(holder: task, id: task.id, focusRequest: editorFocus, onEscape: back)
        }
        .background(hiddenShortcuts)
        .onAppear(perform: load)
        .onChange(of: task.id) { _, _ in load() }
        .onChange(of: task.title) { _, newTitle in
            if !isTitleFocused { title = newTitle }
        }
        .onDisappear(perform: commitTitle)
    }

    // MARK: Top bar

    /// The header island (#116): back to where the task was opened from,
    /// then previous, next and the task's options.
    private var topBar: some View {
        HeaderIsland {
            Button(action: back) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(originTitle)
                        .lineLimit(1)
                }
                .padding(.leading, 6)
                .padding(.trailing, 10)
                .frame(height: 28)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to \(originTitle)  Esc")
            .padding(.leading, -6)

            Text("/").foregroundStyle(SchemaTheme.inkFaint)
            Text(task.title)
                .foregroundStyle(SchemaTheme.ink)
                .truncationMode(.tail)
        } trailing: {
            SchemaIconButton(systemImage: "chevron.up", label: "Previous task", shortcut: "⌘[", size: 32) {
                actions.onPrevious?()
            }
            .disabled(actions.onPrevious == nil)
            SchemaIconButton(systemImage: "chevron.down", label: "Next task", shortcut: "⌘]", size: 32) {
                actions.onNext?()
            }
            .disabled(actions.onNext == nil)
            optionsMenu
        }
    }

    private var optionsMenu: some View {
        SchemaMenuButton("Task options") {
            SchemaMenuItem.submenu("Move to") {
                for page in actions.movePages {
                    SchemaMenuItem.action(page.title, isChecked: page.id == task.list?.id, isDisabled: page.id == task.list?.id) { actions.onMove(page) }
                }
            }
            SchemaMenuItem.action("Duplicate", shortcut: "\u{2318}D", actions.onDuplicate)
            SchemaMenuItem.divider
            SchemaMenuItem.action("Delete task\u{2026}", isDestructive: true, actions.onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SchemaTheme.ink)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .fixedSize()
        .help("Task options")
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            SchemaCheckbox(
                isChecked: task.isCompleted,
                isBlocked: isBlocked,
                size: 24,
                label: task.title,
                hitPadding: 4,
                action: actions.onToggle
            )
            .padding(.top, 7)

            TextField("Task title", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.spaceGrotesk(32, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(task.isCompleted ? SchemaTheme.inkMuted : SchemaTheme.ink)
                .strikethrough(task.isCompleted, color: SchemaTheme.inkMuted)
                .lineLimit(1...4)
                .focused($isTitleFocused)
                .onSubmit {
                    commitTitle()
                    editorFocus = EditorFocusRequest(position: .start)
                }
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused { commitTitle() }
                }
                .accessibilityLabel("Task title")
        }
        .padding(.leading, PageBodyEditor.gutterWidth)
        .padding(.top, 12)
    }

    /// Esc goes back; ⌘[ and ⌘] step through the list.
    private var hiddenShortcuts: some View {
        Group {
            Button("Back", action: back)
                .keyboardShortcut(.cancelAction)
            Button("Previous task") { actions.onPrevious?() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(actions.onPrevious == nil)
            Button("Next task") { actions.onNext?() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(actions.onNext == nil)
        }
        .hidden()
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func back() {
        commitTitle()
        actions.onBack()
    }

    private func commitTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != task.title else {
            if trimmed.isEmpty { title = task.title }
            return
        }
        actions.onRename(trimmed)
    }

    private func load() {
        title = task.title
        // Notes written before tasks had pages become the first line of the body.
        if task.taskDescription != nil {
            PageDocumentMigration.moveNotesIntoDocument(of: task)
            try? modelContext.save()
        }
    }
}

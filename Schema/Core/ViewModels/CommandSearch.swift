//
//  CommandSearch.swift
//  Schema
//
//  What the ⌘K command bar finds (#122): pages, tasks, lines inside pages,
//  and commands. Starting with ">" lists commands only.
//

import Foundation

enum CommandBarAction: Hashable {
    case go(Destination)
    case openTask(UUID)
    /// A line inside a page: opens the page with that line in view.
    case openLine(pageID: UUID, text: String)
    case newPage
    case toggleSidebar
    case toggleDetailsPanel
    case back
    case forward
}

enum CommandBarGroup: String, CaseIterable {
    case pages = "Pages"
    case tasks = "Tasks"
    case lines = "Lines"
    case commands = "Commands"
}

struct CommandBarResult: Identifiable, Hashable {
    let group: CommandBarGroup
    let title: String
    /// Where it lives, or a shortcut for a command.
    var detail = ""
    var keys = ""
    let systemImage: String
    let action: CommandBarAction

    var id: String { "\(group.rawValue)|\(title)|\(detail)|\(action)" }
}

struct CommandSearch {
    struct Page {
        let id: UUID
        let title: String
        let systemImage: String
        let isTag: Bool
        let text: String
    }

    struct Task {
        let id: UUID
        let title: String
        let pageTitle: String
        let isCompleted: Bool
    }

    let pages: [Page]
    let tasks: [Task]

    static let commands: [CommandBarResult] = [
        CommandBarResult(group: .commands, title: "New page", keys: "⌘N", systemImage: "plus", action: .newPage),
        CommandBarResult(group: .commands, title: "Go to Today", systemImage: "sun.max", action: .go(.view(.today))),
        CommandBarResult(group: .commands, title: "Go to Upcoming", systemImage: "calendar", action: .go(.view(.upcoming))),
        CommandBarResult(group: .commands, title: "Go to Everything", keys: "/", systemImage: "tray.full", action: .go(.view(.everything))),
        CommandBarResult(group: .commands, title: "Open Pomodoro", systemImage: "timer", action: .go(.tool(.pomodoro))),
        CommandBarResult(group: .commands, title: "Open Settings", keys: "⌘,", systemImage: "gearshape", action: .go(.tool(.settings))),
        CommandBarResult(group: .commands, title: "Go back", keys: "⌘[", systemImage: "chevron.left", action: .back),
        CommandBarResult(group: .commands, title: "Go forward", keys: "⌘]", systemImage: "chevron.right", action: .forward),
        CommandBarResult(group: .commands, title: "Toggle sidebar", keys: "⌥⌘←", systemImage: "sidebar.left", action: .toggleSidebar),
        CommandBarResult(group: .commands, title: "Toggle overview panel", keys: "⌥⌘→", systemImage: "sidebar.right", action: .toggleDetailsPanel),
    ]

    /// Results in display order: Pages, Tasks, Lines, then Commands.
    func results(for rawQuery: String, limit: Int = 6) -> [CommandBarResult] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(">") {
            let query = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return Self.commands.filter { query.isEmpty || Self.matches($0.title, query) }
        }
        guard !trimmed.isEmpty else {
            // Nothing typed: your pages, then the commands.
            return pages.prefix(limit).map(pageResult) + Self.commands.prefix(4)
        }
        let query = trimmed

        let foundPages = pages
            .filter { Self.matches($0.title, query) }
            .sorted { Self.rank($0.title, query) < Self.rank($1.title, query) }
            .prefix(limit)
            .map(pageResult)

        let foundTasks = tasks
            .filter { Self.matches($0.title, query) }
            .sorted { ($0.isCompleted ? 1 : 0, Self.rank($0.title, query)) < ($1.isCompleted ? 1 : 0, Self.rank($1.title, query)) }
            .prefix(limit)
            .map { CommandBarResult(
                group: .tasks, title: $0.title, detail: $0.pageTitle,
                systemImage: $0.isCompleted ? "checkmark.circle" : "circle", action: .openTask($0.id)
            ) }

        var foundLines: [CommandBarResult] = []
        lines: for page in pages where !page.text.isEmpty {
            for line in page.text.split(whereSeparator: \.isNewline) {
                let text = line.trimmingCharacters(in: .whitespaces)
                guard Self.matches(text, query), text.caseInsensitiveCompare(page.title) != .orderedSame else { continue }
                foundLines.append(CommandBarResult(
                    group: .lines, title: text, detail: page.isTag ? "#\(page.title)" : page.title,
                    systemImage: "text.alignleft", action: .openLine(pageID: page.id, text: text)
                ))
                if foundLines.count >= limit { break lines }
            }
        }

        let foundCommands = Self.commands.filter { Self.matches($0.title, query) }
        return foundPages + foundTasks + foundLines + foundCommands
    }

    private func pageResult(_ page: Page) -> CommandBarResult {
        CommandBarResult(
            group: .pages, title: page.isTag ? "#\(page.title)" : page.title,
            systemImage: page.systemImage, action: .go(.page(page.id))
        )
    }

    /// Every word of the query appears, in any case.
    static func matches(_ text: String, _ query: String) -> Bool {
        query.split(separator: " ").allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// Lower is better: starts with the query, then a word starts with it, then anywhere.
    static func rank(_ text: String, _ query: String) -> Int {
        let lower = text.lowercased(), q = query.lowercased()
        if lower.hasPrefix(q) { return 0 }
        if lower.contains(" " + q) { return 1 }
        return 2
    }
}

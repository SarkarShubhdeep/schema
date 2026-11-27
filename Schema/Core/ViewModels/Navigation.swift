//
//  Navigation.swift
//  Schema
//
//  One value says what the window shows (#118): a page, a view or a tool.
//  Back and forward (⌘[ ⌘]) walk the places you have been.
//

import Foundation
import Observation

/// Views gather tasks from every page; they can't be renamed or deleted.
nonisolated enum ViewKind: String, CaseIterable, Hashable, Sendable {
    case today
    case upcoming
    case everything

    var title: String {
        switch self {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .everything: "Everything"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .everything: "tray.full"
        }
    }

    /// Today and Upcoming filter tasks; Everything shows them all.
    var smartView: SmartView? {
        switch self {
        case .today: .today
        case .upcoming: .upcoming
        case .everything: nil
        }
    }

    init(_ smartView: SmartView) {
        switch smartView {
        case .today: self = .today
        case .upcoming: self = .upcoming
        }
    }
}

/// App screens in the page layout that hold no writing.
nonisolated enum ToolKind: String, CaseIterable, Hashable, Sendable {
    case pomodoro
    case settings

    var title: String {
        switch self {
        case .pomodoro: "Pomodoro"
        case .settings: "Settings"
        }
    }
}

/// Where the window is.
nonisolated enum Destination: Hashable, Sendable {
    case page(UUID)
    case view(ViewKind)
    case tool(ToolKind)

    var pageID: UUID? {
        if case .page(let id) = self { return id }
        return nil
    }

    /// How a pin is saved: "page:<uuid>", "view:today", "tool:pomodoro".
    var storageKey: String {
        switch self {
        case .page(let id): "page:\(id.uuidString)"
        case .view(let kind): "view:\(kind.rawValue)"
        case .tool(let kind): "tool:\(kind.rawValue)"
        }
    }

    init?(storageKey: String) {
        let parts = storageKey.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "page": guard let id = UUID(uuidString: parts[1]) else { return nil }; self = .page(id)
        case "view": guard let kind = ViewKind(rawValue: parts[1]) else { return nil }; self = .view(kind)
        case "tool": guard let kind = ToolKind(rawValue: parts[1]) else { return nil }; self = .tool(kind)
        default: return nil
        }
    }
}

@Observable
@MainActor
final class Navigation {
    /// What the window shows now.
    private(set) var destination: Destination
    private(set) var backStack: [Destination] = []
    private(set) var forwardStack: [Destination] = []

    /// How many places back remembers.
    private let limit = 50

    init(destination: Destination = .view(.today)) {
        self.destination = destination
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Goes to `destination`; going where you already are does nothing.
    func go(to destination: Destination) {
        guard destination != self.destination else { return }
        backStack.append(self.destination)
        if backStack.count > limit { backStack.removeFirst(backStack.count - limit) }
        forwardStack.removeAll()
        self.destination = destination
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(destination)
        destination = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(destination)
        destination = next
    }

    /// Forgets a page that no longer exists; if it is open, goes back past it.
    func forget(page id: UUID, fallback: Destination = .view(.today)) {
        let gone: (Destination) -> Bool = { $0.pageID == id }
        backStack.removeAll(where: gone)
        forwardStack.removeAll(where: gone)
        // Drop repeats left next to each other.
        backStack = backStack.reduce(into: []) { if $0.last != $1 { $0.append($1) } }
        if destination.pageID == id {
            destination = backStack.popLast() ?? fallback
        }
    }
}

//
//  SchemaMenuItem.swift
//  Schema
//
//  Schema's own menus (#83): what a menu holds, and how the keyboard moves
//  through it. macOS menus can't take Schema's look, so dropdowns, ⋯ menus
//  and right-click menus are drawn by Schema in one style, the same as the
//  editor's (Menus board on the canvas).
//

import Foundation

/// One row of a menu: something to do, a submenu, a small section label or a divider.
struct SchemaMenuItem: Identifiable {
    enum Kind {
        case action(() -> Void)
        case submenu([SchemaMenuItem])
        case header
        case divider
    }

    let id = UUID()
    var title: String
    var kind: Kind
    /// A check on the left: the current choice, or a setting that is on.
    var isChecked = false
    /// Shown on the right in Space Grotesk, e.g. "⌘R". Display only: the
    /// shortcut itself is set up where the command lives.
    var shortcut: String?
    /// Red. Delete is always last, after a divider.
    var isDestructive = false
    var isDisabled = false

    var isChoosable: Bool {
        switch kind {
        case .action, .submenu: !isDisabled
        case .header, .divider: false
        }
    }

    var submenu: [SchemaMenuItem]? {
        if case .submenu(let items) = kind { items } else { nil }
    }

    static func action(
        _ title: String,
        shortcut: String? = nil,
        isChecked: Bool = false,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        _ run: @escaping () -> Void
    ) -> SchemaMenuItem {
        SchemaMenuItem(title: title, kind: .action(run), isChecked: isChecked, shortcut: shortcut, isDestructive: isDestructive, isDisabled: isDisabled)
    }

    static func submenu(_ title: String, isDisabled: Bool = false, @SchemaMenuBuilder _ items: () -> [SchemaMenuItem]) -> SchemaMenuItem {
        let items = items()
        return SchemaMenuItem(title: title, kind: .submenu(items), isDisabled: isDisabled || !items.contains(where: \.isChoosable))
    }

    static func header(_ title: String) -> SchemaMenuItem {
        SchemaMenuItem(title: title, kind: .header)
    }

    static var divider: SchemaMenuItem {
        SchemaMenuItem(title: "", kind: .divider)
    }
}

/// Builds menus like SwiftUI views: `if`, `for` and plain items.
@resultBuilder
enum SchemaMenuBuilder {
    static func buildExpression(_ item: SchemaMenuItem) -> [SchemaMenuItem] { [item] }
    static func buildExpression(_ items: [SchemaMenuItem]) -> [SchemaMenuItem] { items }
    static func buildBlock(_ parts: [SchemaMenuItem]...) -> [SchemaMenuItem] { parts.flatMap { $0 } }
    static func buildOptional(_ part: [SchemaMenuItem]?) -> [SchemaMenuItem] { part ?? [] }
    static func buildEither(first part: [SchemaMenuItem]) -> [SchemaMenuItem] { part }
    static func buildEither(second part: [SchemaMenuItem]) -> [SchemaMenuItem] { part }
    static func buildArray(_ parts: [[SchemaMenuItem]]) -> [SchemaMenuItem] { parts.flatMap { $0 } }

    /// Dividers only between groups: none first, last or twice in a row.
    static func buildFinalResult(_ items: [SchemaMenuItem]) -> [SchemaMenuItem] {
        var result: [SchemaMenuItem] = []
        for item in items {
            if case .divider = item.kind {
                guard let last = result.last else { continue }
                if case .divider = last.kind { continue }
            }
            result.append(item)
        }
        if let last = result.last, case .divider = last.kind { result.removeLast() }
        return result
    }
}

/// Where the keyboard is in a menu: ↑ ↓ skip headers, dividers and
/// disabled rows and wrap around; typing letters jumps to a matching row.
struct SchemaMenuNavigator {
    let items: [SchemaMenuItem]
    /// Index into `items`, or nil before the first key or hover.
    var selected: Int?
    private var typed = ""
    private var lastTyped = Date.distantPast

    init(items: [SchemaMenuItem], selected: Int? = nil) {
        self.items = items
        self.selected = selected
    }

    var selectedItem: SchemaMenuItem? { selected.map { items[$0] } }

    mutating func moveDown() { move(by: 1) }
    mutating func moveUp() { move(by: -1) }

    mutating func move(by step: Int) {
        let choosable = items.indices.filter { items[$0].isChoosable }
        guard !choosable.isEmpty else { selected = nil; return }
        guard let current = selected, let at = choosable.firstIndex(of: current) else {
            selected = step > 0 ? choosable.first : choosable.last
            return
        }
        selected = choosable[(at + step + choosable.count) % choosable.count]
    }

    /// Type-to-select: letters typed within a second add up ("de" → Delete).
    mutating func type(_ text: String, at now: Date = .now) {
        typed = now.timeIntervalSince(lastTyped) < 1 ? typed + text.lowercased() : text.lowercased()
        lastTyped = now
        let match = items.indices.first { items[$0].isChoosable && items[$0].title.lowercased().hasPrefix(typed) }
            ?? items.indices.first { items[$0].isChoosable && items[$0].title.lowercased().hasPrefix(text.lowercased()) }
        if let match { selected = match }
    }
}

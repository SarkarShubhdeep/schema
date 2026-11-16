//
//  SchemaBlock.swift
//  Schema
//
//  One line of content on a scratchpad page or in a task's body (schema V6).
//  Blocks are a flat list ordered by `sortIndex`; nesting comes later.
//

import Foundation
import SwiftData

/// What a block shows. Stored as its raw value so new kinds can be added
/// without a migration; unknown values read as `.text`.
enum BlockKind: String, CaseIterable, Sendable {
    case text
    case heading
    case bullet
    case todo
    case quote
    case divider

    /// Only to-do blocks can be checked or turned into tasks.
    var isCheckable: Bool { self == .todo }

    /// Dividers hold no text.
    var holdsText: Bool { self != .divider }
}

@Model
final class SchemaBlock {
    var id: UUID
    var kindRaw: String = BlockKind.text.rawValue
    var text: String = ""
    var isChecked: Bool = false
    var sortIndex: Double = 0
    var createdAt: Date
    var updatedAt: Date
    /// The task made from this line with "Make task" (#40). The line stays
    /// in the note; this links it to the task in a to-do list.
    var linkedTaskID: UUID?

    /// Set when the block belongs to a scratchpad page.
    var page: SchemaList?
    /// Set when the block belongs to a task's body (tasks as pages, #31).
    var task: SchemaTask?

    init(
        kind: BlockKind = .text,
        text: String = "",
        sortIndex: Double,
        page: SchemaList? = nil,
        task: SchemaTask? = nil
    ) {
        let now = Date()
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.text = kind.holdsText ? text : ""
        self.isChecked = false
        self.sortIndex = sortIndex
        self.createdAt = now
        self.updatedAt = now
        self.page = page
        self.task = task
    }
}

extension SchemaBlock {
    var kind: BlockKind {
        get { BlockKind(rawValue: kindRaw) ?? .text }
        set {
            kindRaw = newValue.rawValue
            if !newValue.isCheckable { isChecked = false }
            if !newValue.holdsText { text = "" }
            updatedAt = .now
        }
    }
}

/// Sort keys for ordered blocks. Inserting between two neighbours takes the
/// midpoint, so only the new block is written; `renumbered` spaces them out
/// again when the gap gets too small to split.
enum BlockOrdering {
    static let step: Double = 1
    /// Below this gap, midpoints lose precision; renumber first.
    static let minimumGap: Double = 1e-9

    /// Sort index for a block placed between `before` and `after`
    /// (either may be nil at the ends of the list).
    static func index(between before: Double?, and after: Double?) -> Double {
        switch (before, after) {
        case (nil, nil):
            return step
        case let (before?, nil):
            return before + step
        case let (nil, after?):
            return after - step
        case let (before?, after?):
            return (before + after) / 2
        }
    }

    /// True when the gap between two neighbours is too small to split.
    static func needsRenumbering(between before: Double, and after: Double) -> Bool {
        after - before < minimumGap
    }

    /// Evenly spaced indices (1, 2, 3, …) for `count` blocks.
    static func renumbered(count: Int) -> [Double] {
        (0..<count).map { Double($0 + 1) * step }
    }
}

extension Array where Element == SchemaBlock {
    /// Blocks in display order: by `sortIndex`, then creation time.
    var inDisplayOrder: [SchemaBlock] {
        sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.createdAt < $1.createdAt
        }
    }
}

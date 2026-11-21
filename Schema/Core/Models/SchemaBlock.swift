//
//  SchemaBlock.swift
//  Schema
//
//  One line of content on a scratchpad page or in a task's body (schema V6).
//  Since V7 (#77) content lives in one TipTap document per page and the
//  block editor is gone (#82); blocks are kept for the migration that moves
//  old lines into documents, and BlockKind for building documents from lines.
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

extension Array where Element == SchemaBlock {
    /// Blocks in display order: by `sortIndex`, then creation time.
    var inDisplayOrder: [SchemaBlock] {
        sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.createdAt < $1.createdAt
        }
    }
}

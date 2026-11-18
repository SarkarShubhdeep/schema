//
//  SchemaList.swift
//  Schema
//

import Foundation
import SwiftData

/// What a page holds (schema V6). Fixed when the page is created.
enum PageKind: String, CaseIterable, Sendable {
    /// Tasks, as lists have always worked.
    case todo
    /// Free-form notes: one TipTap document.
    case scratchpad
}

@Model
final class SchemaList: PageDocumentHolder {
    var id: UUID
    var title: String
    var createdAt: Date
    var order: Int
    var accentColorName: String?
    var tagLabel: String?
    /// `PageKind` raw value. Pages from before V6 are to-do lists.
    var pageKindRaw: String = PageKind.todo.rawValue

    @Relationship(deleteRule: .cascade, inverse: \SchemaTask.list)
    var tasks: [SchemaTask]

    /// V6 lines; empty since V7 moved them into `documentData`.
    @Relationship(deleteRule: .cascade, inverse: \SchemaBlock.page)
    var blocks: [SchemaBlock] = []

    // The page body as one TipTap document (schema V7, #77), and what is
    // derived from it on save so lists and search never parse it.
    @Attribute(.externalStorage) var documentData: Data?
    var documentText: String = ""
    var linkedTaskIDsRaw: String = ""
    var checklistCount: Int = 0
    var checklistDoneCount: Int = 0
    var documentEditedAt: Date?

    init(
        title: String,
        order: Int = 0,
        accentColorName: String? = nil,
        tagLabel: String? = nil,
        kind: PageKind = .todo
    ) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
        self.order = order
        self.accentColorName = accentColorName
        self.tagLabel = tagLabel
        self.pageKindRaw = kind.rawValue
        self.tasks = []
        self.blocks = []
    }
}

extension SchemaList {
    static let everythingTitle = "Everything"

    var pageKind: PageKind {
        PageKind(rawValue: pageKindRaw) ?? .todo
    }

    var isScratchpad: Bool { pageKind == .scratchpad }

    /// Tasks can be added to or moved into this page: to-do lists only.
    var acceptsTasks: Bool { !isEverythingList && pageKind == .todo }

    var isEverythingList: Bool {
        title == Self.everythingTitle
    }

    var displayTagLabel: String {
        if let tagLabel, !tagLabel.isEmpty {
            return tagLabel
        }
        return title
    }

    var incompleteTasks: [SchemaTask] {
        tasks.filter { !$0.isCompleted }.sorted { $0.createdAt < $1.createdAt }
    }

    var completedTasks: [SchemaTask] {
        tasks.filter(\.isCompleted).sorted { $0.createdAt < $1.createdAt }
    }

    var incompleteTaskCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
}

//
//  PageDocumentMigration.swift
//  Schema
//
//  The V6 → V7 step (#77): each page's and task's lines become one TipTap
//  document. Bullets and to-dos group into lists, a to-do keeps its tick
//  and its link to the task it was made into, and a task's older notes
//  field becomes the first line of its body. The lines are then deleted.
//

import Foundation
import SwiftData

enum PageDocumentMigration {
    static func moveBlocksIntoDocuments(in context: ModelContext) throws {
        for page in try context.fetch(FetchDescriptor<SchemaList>()) where !page.blocks.isEmpty {
            moveBlocks(page.blocks, into: page, context: context)
        }
        for task in try context.fetch(FetchDescriptor<SchemaTask>()) {
            if !task.blocks.isEmpty {
                moveBlocks(task.blocks, into: task, context: context)
            }
            moveNotesIntoDocument(of: task)
        }
        // Lines no page or task owns any more have nowhere to go.
        for block in try context.fetch(FetchDescriptor<SchemaBlock>()) {
            context.delete(block)
        }
    }

    /// A task's notes from before tasks had pages become its first line,
    /// above any body it already has. (v0.5 only moved them into an empty
    /// body, so a task could have both; #84.)
    static func moveNotesIntoDocument(of task: SchemaTask) {
        guard let notes = task.taskDescription?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        defer { task.taskDescription = nil }
        guard !notes.isEmpty else { return }
        let line = TipTapDocument.Line(kind: .text, text: notes)
        if task.hasDocument {
            task.setDocument(PageDocument.prepending([line], to: task.documentJSON), editedAt: task.documentEditedAt ?? task.createdAt)
        } else {
            task.setDocument(TipTapDocument.json(TipTapDocument.document(from: [line])), editedAt: task.createdAt)
        }
    }

    /// Notes still in the old field after updating to 0.5.1, where tasks
    /// with a body kept them out of sight (#84): moved in once at launch.
    static func moveLeftoverNotes(in context: ModelContext) {
        let leftover = (try? context.fetch(FetchDescriptor<SchemaTask>(predicate: #Predicate { $0.taskDescription != nil }))) ?? []
        guard !leftover.isEmpty else { return }
        for task in leftover { moveNotesIntoDocument(of: task) }
        try? context.save()
    }

    private static func moveBlocks(_ blocks: [SchemaBlock], into holder: some PageDocumentHolder, context: ModelContext) {
        let edited = blocks.map(\.updatedAt).max() ?? .now
        holder.setDocument(TipTapDocument.json(TipTapDocument.document(from: blocks)), editedAt: edited)
        for block in blocks { context.delete(block) }
    }
}

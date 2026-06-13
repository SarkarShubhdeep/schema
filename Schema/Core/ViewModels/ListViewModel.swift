//
//  ListViewModel.swift
//  Schema
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ListViewModel {
    private let modelContext: ModelContext

    var selectedListID: UUID?
    var showNewListSheet = false
    var newListTitle = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func ensureDefaultListsIfNeeded(from lists: [SchemaList]) {
        guard lists.isEmpty else { return }

        let everything = SchemaList(title: SchemaList.everythingTitle, order: 0)
        let dailyTodos = SchemaList(title: "Daily Todos", order: 1)

        modelContext.insert(everything)
        modelContext.insert(dailyTodos)
        save()
        selectedListID = everything.id
    }

    func selectList(_ list: SchemaList?) {
        selectedListID = list?.id
    }

    func selectList(at index: Int, from lists: [SchemaList]) {
        guard lists.indices.contains(index) else { return }
        selectedListID = lists[index].id
    }

    func selectedList(from lists: [SchemaList]) -> SchemaList? {
        if let selectedListID {
            return lists.first(where: { $0.id == selectedListID })
        }
        return lists.first
    }

    func createList(title: String, existingLists: [SchemaList]) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextOrder = (existingLists.map(\.order).max() ?? -1) + 1
        let list = SchemaList(title: trimmed, order: nextOrder)
        modelContext.insert(list)
        save()
        selectedListID = list.id
        newListTitle = ""
        showNewListSheet = false
    }

    func deleteList(_ list: SchemaList, from lists: [SchemaList]) {
        guard !list.isEverythingList else { return }

        if selectedListID == list.id {
            selectedListID = lists.first(where: { $0.id != list.id })?.id
        }

        modelContext.delete(list)
        save()
    }

    func reorderLists(_ lists: [SchemaList]) {
        for (index, list) in lists.enumerated() {
            list.order = index
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save lists: \(error)")
        }
    }
}

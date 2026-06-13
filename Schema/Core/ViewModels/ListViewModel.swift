//
//  ListViewModel.swift
//  Schema
//

import Foundation
import SwiftData
import Observation

enum TaskSortOption: String, CaseIterable, Identifiable {
    case manual
    case createdAt
    case reminderTime
    case alphabetical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .createdAt: "Date Created"
        case .reminderTime: "Reminder Time"
        case .alphabetical: "Alphabetical"
        }
    }
}

enum TaskFilterOption: String, CaseIterable, Identifiable {
    case all
    case withReminder
    case withoutReminder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All Tasks"
        case .withReminder: "With Reminder"
        case .withoutReminder: "Without Reminder"
        }
    }
}

@Observable
@MainActor
final class ListViewModel {
    private let modelContext: ModelContext

    var selectedListID: UUID?
    var showNewListSheet = false
    var newListTitle = ""
    var sortOption: TaskSortOption = .manual
    var filterOption: TaskFilterOption = .all
    var defaultWritableListID: UUID?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func ensureDefaultListsIfNeeded(from lists: [SchemaList]) {
        guard lists.isEmpty else { return }

        let everything = SchemaList(
            title: SchemaList.everythingTitle,
            order: 0,
            accentColorName: SchemaListColorName.neutral.rawValue
        )
        let dailyTodos = SchemaList(
            title: "Daily Todos",
            order: 1,
            accentColorName: SchemaListColorName.grey.rawValue,
            tagLabel: "Daily todo"
        )
        let githubWork = SchemaList(
            title: "Github Work",
            order: 2,
            accentColorName: SchemaListColorName.blue.rawValue,
            tagLabel: "Github"
        )
        let groceries = SchemaList(
            title: "Groceries",
            order: 3,
            accentColorName: SchemaListColorName.purple.rawValue,
            tagLabel: "Groceries"
        )

        modelContext.insert(everything)
        modelContext.insert(dailyTodos)
        modelContext.insert(githubWork)
        modelContext.insert(groceries)
        save()
        selectedListID = everything.id
        defaultWritableListID = dailyTodos.id
    }

    func selectList(_ list: SchemaList?) {
        selectedListID = list?.id
    }

    func selectList(at index: Int, from lists: [SchemaList]) {
        guard lists.indices.contains(index) else { return }
        selectedListID = lists[index].id
    }

    func selectNextList(from lists: [SchemaList]) {
        guard !lists.isEmpty else { return }

        guard let currentListID = selectedListID,
              let currentIndex = lists.firstIndex(where: { $0.id == currentListID }) else {
            selectedListID = lists.first?.id
            return
        }

        let nextIndex = (currentIndex + 1) % lists.count
        selectedListID = lists[nextIndex].id
    }

    func selectPreviousList(from lists: [SchemaList]) {
        guard !lists.isEmpty else { return }

        guard let currentListID = selectedListID,
              let currentIndex = lists.firstIndex(where: { $0.id == currentListID }) else {
            selectedListID = lists.first?.id
            return
        }

        let previousIndex = currentIndex == 0 ? lists.count - 1 : currentIndex - 1
        selectedListID = lists[previousIndex].id
    }

    func selectEverythingList(from lists: [SchemaList]) {
        selectedListID = lists.first(where: \.isEverythingList)?.id ?? lists.first?.id
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
        let list = SchemaList(
            title: trimmed,
            order: nextOrder,
            accentColorName: SchemaListColorName.fallback(for: trimmed).rawValue
        )
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

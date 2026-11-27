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

    /// Where the window is (#118). Everything below reads from it.
    let navigation: Navigation

    var destination: Destination { navigation.destination }

    /// What's under an open task page; otherwise the destination (#124).
    var context: Destination { navigation.context }

    /// The open page (or the one under a task page); `nil` for views and tools.
    var selectedListID: UUID? { context.pageID }

    /// Today or Upcoming, shown over every task. `nil` otherwise.
    var smartView: SmartView? {
        if case .view(let kind) = context { return kind.smartView }
        return nil
    }

    /// The Pomodoro page (#89).
    var showsPomodoro: Bool { context == .tool(.pomodoro) }

    /// Everything is open (the view over every task).
    var showsEverything: Bool { context == .view(.everything) }

    var showNewListSheet = false
    var newListTitle = ""
    var newPageKind: PageKind = .todo
    var sortOption: TaskSortOption = SchemaPreferences.sortOption {
        didSet { SchemaPreferences.sortOption = sortOption }
    }
    var filterOption: TaskFilterOption = SchemaPreferences.filterOption {
        didSet { SchemaPreferences.filterOption = filterOption }
    }
    var defaultWritableListID: UUID? = SchemaPreferences.defaultWritableListID {
        didSet { SchemaPreferences.defaultWritableListID = defaultWritableListID }
    }

    init(modelContext: ModelContext, navigation: Navigation? = nil) {
        self.modelContext = modelContext
        self.navigation = navigation ?? Navigation()
    }

    func go(to destination: Destination) {
        navigation.go(to: destination)
    }

    // MARK: Pins (#119)

    /// Pinned pages and views, in order. Pinning doesn't move anything: the
    /// item keeps its place in its own section too.
    private(set) var pinned: [Destination] = SchemaPreferences.pinnedDestinations {
        didSet { SchemaPreferences.pinnedDestinations = pinned }
    }

    func isPinned(_ destination: Destination) -> Bool {
        pinned.contains(destination)
    }

    /// Pins at the end of the Pinned section, or unpins.
    func togglePin(_ destination: Destination) {
        if let index = pinned.firstIndex(of: destination) {
            pinned.remove(at: index)
        } else {
            pinned.append(destination)
        }
    }

    /// Puts `moving` where `target` is now in the Pinned section.
    func movePin(_ moving: Destination, to target: Destination) {
        guard moving != target,
              let from = pinned.firstIndex(of: moving),
              let to = pinned.firstIndex(of: target) else { return }
        let item = pinned.remove(at: from)
        pinned.insert(item, at: to)
    }

    /// Pins whose page still exists, in order.
    func pinnedDestinations(existingIn lists: [SchemaList]) -> [Destination] {
        let ids = Set(lists.map(\.id))
        return pinned.filter { $0.pageID.map(ids.contains) ?? true }
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
        defaultWritableListID = dailyTodos.id
        SchemaPreferences.defaultWritableListID = dailyTodos.id
    }

    /// Opens a page; the stored Everything list opens the Everything view.
    func selectList(_ list: SchemaList?) {
        guard let list else { return }
        go(to: list.isEverythingList ? .view(.everything) : .page(list.id))
    }

    func selectList(id: UUID, from lists: [SchemaList]) {
        selectList(lists.first { $0.id == id })
    }

    func selectList(at index: Int, from lists: [SchemaList]) {
        guard lists.indices.contains(index) else { return }
        selectList(lists[index])
    }

    func selectNextList(from lists: [SchemaList]) {
        step(by: 1, through: lists)
    }

    func selectPreviousList(from lists: [SchemaList]) {
        step(by: -1, through: lists)
    }

    /// ⌃Tab walks the pages in sidebar order, wrapping around.
    private func step(by offset: Int, through lists: [SchemaList]) {
        let pages = pages(from: lists)
        guard !pages.isEmpty else { return }
        guard let current = selectedListID, let index = pages.firstIndex(where: { $0.id == current }) else {
            selectList(offset > 0 ? pages.first : pages.last)
            return
        }
        selectList(pages[(index + offset + pages.count) % pages.count])
    }

    func selectPomodoro(from lists: [SchemaList] = []) {
        go(to: .tool(.pomodoro))
    }

    func selectSmartView(_ view: SmartView, from lists: [SchemaList] = []) {
        go(to: .view(ViewKind(view)))
    }

    /// Pages in sidebar order: every list except Everything.
    /// To-do lists only: where tasks can be added or moved.
    func taskPages(from lists: [SchemaList]) -> [SchemaList] {
        lists.filter(\.acceptsTasks)
    }

    /// Pages in sidebar order: every list except Everything and tag pages,
    /// which have their own section (#102).
    func pages(from lists: [SchemaList]) -> [SchemaList] {
        lists.filter { !$0.isEverythingList && !$0.isTagPage }
    }

    /// Tag pages (#102), by name.
    func tagPages(from lists: [SchemaList]) -> [SchemaList] {
        lists.filter(\.isTagPage).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func selectEverythingList(from lists: [SchemaList] = []) {
        go(to: .view(.everything))
    }

    /// The open page, or the Everything list (every task) while a view is shown.
    func selectedList(from lists: [SchemaList]) -> SchemaList? {
        if let selectedListID, let page = lists.first(where: { $0.id == selectedListID }) {
            return page
        }
        return lists.first(where: \.isEverythingList) ?? lists.first
    }

    func createList(title: String, kind: PageKind = .todo, existingLists: [SchemaList]) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextOrder = (existingLists.map(\.order).max() ?? -1) + 1
        let list = SchemaList(
            title: trimmed,
            order: nextOrder,
            accentColorName: SchemaListColorName.fallback(for: trimmed).rawValue,
            kind: kind
        )
        modelContext.insert(list)
        save()
        go(to: .page(list.id))
        cancelNewPage()
    }

    func openNewPage() {
        newListTitle = ""
        newPageKind = .todo
        showNewListSheet = true
    }

    func cancelNewPage() {
        newListTitle = ""
        newPageKind = .todo
        showNewListSheet = false
    }

    func updateListTitle(_ list: SchemaList, title: String) {
        guard !list.isEverythingList else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != SchemaList.everythingTitle else { return }
        list.title = trimmed
        save()
    }

    func deleteList(_ list: SchemaList, from lists: [SchemaList]) {
        guard !list.isEverythingList else { return }

        navigation.forget(page: list.id)
        pinned.removeAll { $0 == .page(list.id) }

        modelContext.delete(list)
        save()
    }

    /// Puts the page `movingID` where `targetID` is now (#42): after it when
    /// moving down, before it when moving up. Everything keeps its place.
    /// Returns whether anything moved.
    @discardableResult
    func movePage(_ movingID: UUID, to targetID: UUID, in lists: [SchemaList]) -> Bool {
        var pages = pages(from: lists)
        guard movingID != targetID,
              let from = pages.firstIndex(where: { $0.id == movingID }),
              let to = pages.firstIndex(where: { $0.id == targetID }) else { return false }
        let page = pages.remove(at: from)
        pages.insert(page, at: to)
        // Pages take 1…n; Everything, if any, stays at 0 ahead of them.
        for (index, page) in pages.enumerated() {
            page.order = index + 1
        }
        if let everything = lists.first(where: \.isEverythingList) {
            everything.order = 0
        }
        save()
        return true
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

//
//  ManagePagesTests.swift
//  SchemaTests
//
//  Renaming, deleting and reordering pages (#42).
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
private final class RecordingNotifications: NotificationServiceProtocol {
    var cancelled: [UUID] = []
    func requestAuthorization() async throws -> Bool { true }
    func authorizationStatus() async -> NotificationAuthorizationStatus { .authorized }
    func scheduleReminder(for task: SchemaTask) async throws {}
    func cancelReminder(for task: SchemaTask) { cancelled.append(task.id) }
    func rescheduleAllReminders(for tasks: [SchemaTask]) async {}
    func fetchPendingReminders() async -> [SchemaNotificationItem] { [] }
}

@MainActor
struct ManagePagesTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let viewModel: ListViewModel

    init() throws {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        viewModel = ListViewModel(modelContext: container.mainContext)
    }

    /// Everything plus pages A, B, C, D in that order.
    private func makePages() -> [SchemaList] {
        let everything = SchemaList(title: SchemaList.everythingTitle, order: 0)
        context.insert(everything)
        let pages = ["A", "B", "C", "D"].enumerated().map { index, title in
            let page = SchemaList(title: title, order: index + 1)
            context.insert(page)
            return page
        }
        return [everything] + pages
    }

    private func titles(_ lists: [SchemaList]) -> [String] {
        viewModel.pages(from: lists.sorted { $0.order < $1.order }).map(\.title)
    }

    @Test func movingDownTakesTheTargetsPlace() {
        let lists = makePages()
        let a = lists[1], c = lists[3]
        #expect(viewModel.movePage(a.id, to: c.id, in: lists))
        #expect(titles(lists) == ["B", "C", "A", "D"])
    }

    @Test func movingUpTakesTheTargetsPlace() {
        let lists = makePages()
        let b = lists[2], d = lists[4]
        viewModel.movePage(d.id, to: b.id, in: lists)
        #expect(titles(lists) == ["A", "D", "B", "C"])
    }

    @Test func everythingStaysFirst() {
        let lists = makePages()
        viewModel.movePage(lists[4].id, to: lists[1].id, in: lists)
        #expect(lists.sorted { $0.order < $1.order }.first?.isEverythingList == true)
    }

    @Test func droppingOnItselfChangesNothing() {
        let lists = makePages()
        #expect(!viewModel.movePage(lists[2].id, to: lists[2].id, in: lists))
        #expect(titles(lists) == ["A", "B", "C", "D"])
    }

    @Test func pagesCannotBeRenamedEverythingOrBlank() {
        let page = SchemaList(title: "Work")
        context.insert(page)
        viewModel.updateListTitle(page, title: SchemaList.everythingTitle)
        viewModel.updateListTitle(page, title: "   ")
        #expect(page.title == "Work")
        viewModel.updateListTitle(page, title: "  Studio ")
        #expect(page.title == "Studio")
    }

    @Test func deletingAPageDeletesItsTasksAndCancelsReminders() throws {
        let notifications = RecordingNotifications()
        let tasks = TaskViewModel(modelContext: context, notificationService: notifications)
        let work = SchemaList(title: "Work")
        let home = SchemaList(title: "Home")
        context.insert(work)
        context.insert(home)
        let first = SchemaTask(title: "Draft", list: work)
        let second = SchemaTask(title: "Send", list: work)
        let elsewhere = SchemaTask(title: "Laundry", list: home)
        // A routine on another page that follows a task on this one.
        elsewhere.afterTaskID = first.id
        [first, second, elsewhere].forEach(context.insert)
        try context.save()

        tasks.deleteTasks(onPage: work)
        viewModel.selectList(home)
        viewModel.selectList(work)
        viewModel.deleteList(work, from: [work, home])

        let remaining = try context.fetch(FetchDescriptor<SchemaTask>())
        #expect(remaining.map(\.title) == ["Laundry"])
        #expect(Set(notifications.cancelled) == [first.id, second.id])
        #expect(elsewhere.afterTaskID == nil)
        #expect(try context.fetch(FetchDescriptor<SchemaList>()).map(\.title) == ["Home"])
        // Deleting the open page goes back to where you were (#118).
        #expect(viewModel.selectedListID == home.id)
        #expect(!tasks.canUndo)
    }
}

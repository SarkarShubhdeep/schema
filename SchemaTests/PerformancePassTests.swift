//
//  PerformancePassTests.swift
//  SchemaTests
//
//  The code rewritten for speed in #45 keeps its behaviour: day stats,
//  linked routines, sorting by key, open/done in one pass, and the model
//  store that replaced @Query.
//

import Foundation
import SwiftData
import Testing
@testable import Schema

@MainActor
struct PerformancePassTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    /// Noon on a Wednesday, so yesterday and tomorrow are in the same week
    /// whichever day the week starts on.
    private var noon: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 18
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    private func hours(_ offset: Double) -> Date { noon.addingTimeInterval(offset * 3600) }

    // MARK: Day stats

    @Test func dayStatsCountsInOnePass() {
        let calendar = Calendar.schema(weekStart: .monday)
        let page = SchemaList(title: "Daily")
        let other = SchemaList(title: "Work")
        context.insert(page)
        context.insert(other)

        let doneToday = SchemaTask(title: "Done today", list: page)
        doneToday.setCompleted(true, at: hours(-2))
        let doneYesterday = SchemaTask(title: "Done yesterday", list: page)
        doneYesterday.setCompleted(true, at: hours(-24))
        let laterToday = SchemaTask(title: "Later today", list: page, reminderTime: hours(3))
        let soonToday = SchemaTask(title: "Soon today", list: page, reminderTime: hours(1))
        let overdue = SchemaTask(title: "Overdue", list: page, reminderTime: hours(-30))
        let tomorrow = SchemaTask(title: "Tomorrow", list: other, reminderTime: hours(24))
        let routineOpen = SchemaTask(title: "Stretch", list: page, isRoutine: true)
        let routineDone = SchemaTask(title: "Plan", list: page, isRoutine: true)
        routineDone.setCompleted(true, at: hours(-1))
        let someday = SchemaTask(title: "Someday", list: other)
        let tasks = [doneToday, doneYesterday, laterToday, soonToday, overdue, tomorrow, routineOpen, routineDone, someday]
        tasks.forEach(context.insert)

        let stats = DayStats(tasks: tasks, pages: [page, other], now: noon, calendar: calendar, reminderLimit: 2)

        #expect(stats.doneToday == 2)
        // Later today, soon today, overdue, and the open routine with no time.
        #expect(stats.dueToday == 4)
        #expect(stats.nextDueTime == hours(1))
        #expect(stats.reminders.map(\.title) == ["Soon today", "Later today"])
        #expect(stats.reminders.first?.pageTitle == "Daily")
        #expect(stats.weekTotal == 3)
        #expect(stats.week.first { $0.isToday }?.count == 2)
        #expect(stats.routines.count == 1)
        #expect(stats.routines.first?.done == 1)
        #expect(stats.routines.first?.total == 2)
    }

    // MARK: Routines

    @Test func connectedRoutinesAreFoundPerPage() {
        let linked = SchemaList(title: "Linked")
        let loose = SchemaList(title: "Loose")
        let everything = SchemaList(title: SchemaList.everythingTitle, order: 0)
        [linked, loose, everything].forEach(context.insert)
        let first = SchemaTask(title: "Wake", list: linked, isRoutine: true)
        let second = SchemaTask(title: "Stretch", list: linked, isRoutine: true, afterTaskID: first.id)
        let alone = SchemaTask(title: "Read", list: loose, isRoutine: true)
        let plain = SchemaTask(title: "Email", list: loose)
        let tasks = [first, second, alone, plain]
        tasks.forEach(context.insert)

        #expect(RoutineSequenceOrdering.listsWithConnectedRoutines(in: tasks) == [linked.id])
        #expect(RoutineSequenceOrdering.requiresManualSort(for: linked, in: tasks))
        #expect(!RoutineSequenceOrdering.requiresManualSort(for: loose, in: tasks))
        #expect(RoutineSequenceOrdering.requiresManualSort(for: everything, in: tasks))
        #expect(!RoutineSequenceOrdering.requiresManualSort(for: everything, in: [alone, plain]))
    }

    // MARK: Sorting and partitioning

    @Test func sortingByKeyKeepsTheOrder() {
        let page = SchemaList(title: "Inbox")
        context.insert(page)
        let tasks = ["banana", "Apple", "cherry"].map { SchemaTask(title: $0, list: page) }
        tasks.forEach(context.insert)
        let sorted = tasks.sorted(byKey: \.title) { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        #expect(sorted.map(\.title) == ["Apple", "banana", "cherry"])
    }

    @Test func openAndDoneComeFromOnePass() {
        let page = SchemaList(title: "Inbox")
        context.insert(page)
        let tasks = (1...4).map { index in
            let task = SchemaTask(title: "Task \(index)", list: page)
            task.manualSortIndex = Double(5 - index)
            if index.isMultiple(of: 2) { task.setCompleted(true) }
            return task
        }
        tasks.forEach(context.insert)
        let viewModel = TaskViewModel(modelContext: context, notificationService: NotificationService())
        let (open, done) = viewModel.partitionedTasks(for: page, from: tasks)
        #expect(open.map(\.title) == ["Task 3", "Task 1"])
        #expect(done.map(\.title) == ["Task 4", "Task 2"])
    }

    // MARK: Model store

    @Test func modelStoreFollowsInsertsAndDeletes() throws {
        let store = ModelStore<SchemaTask>(context: context)
        #expect(store.items.isEmpty)

        let task = SchemaTask(title: "New")
        context.insert(task)
        try context.save()
        #expect(store.items.map(\.title) == ["New"])

        // Editing a property needs no fetch: the same model is in the store.
        task.title = "Renamed"
        try context.save()
        #expect(store.items.map(\.title) == ["Renamed"])

        context.delete(task)
        try context.save()
        #expect(store.items.isEmpty)
    }

    @Test func modelStoreIgnoresOtherModels() throws {
        let store = ModelStore<SchemaTask>(context: context)
        let page = SchemaList(title: "Ideas", kind: .scratchpad)
        context.insert(page)
        context.insert(SchemaBlock(kind: .text, text: "Hello", sortIndex: 1, page: page))
        try context.save()
        #expect(store.items.isEmpty)
    }

    // MARK: Memo

    @Test func memoKeepsItsValueUntilSomethingItReadChanges() {
        let task = SchemaTask(title: "Draft")
        context.insert(task)
        let memo = ObservedMemo<String>()
        var computed = 0
        func read() -> String {
            memo.value(key: 0) {
                computed += 1
                return task.title
            }
        }

        #expect(read() == "Draft")
        #expect(read() == "Draft")
        #expect(computed == 1)

        task.title = "Send"
        #expect(read() == "Send")
        #expect(computed == 2)

        // A different key also recomputes.
        #expect(memo.value(key: 1) { computed += 1; return task.title } == "Send")
        #expect(computed == 3)
    }
}

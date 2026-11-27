//
//  CommandSearchTests.swift
//  SchemaTests
//
//  The ⌘K command bar's search (#122).
//

import Foundation
import Testing
@testable import Schema

struct CommandSearchTests {
    let lisbon = UUID(), groceries = UUID(), flights = UUID()

    var search: CommandSearch {
        CommandSearch(
            pages: [
                .init(id: groceries, title: "Groceries", systemImage: "checklist", isTag: false, text: ""),
                .init(id: lisbon, title: "Trip to Lisbon", systemImage: "doc", isTag: false, text: "Trip to Lisbon\nPack for Lisbon rain\nBooks"),
            ],
            tasks: [
                .init(id: flights, title: "Book the Lisbon flights", pageTitle: "Travel", isCompleted: false),
                .init(id: UUID(), title: "Milk", pageTitle: "Groceries", isCompleted: false),
            ]
        )
    }

    @Test func findsPagesTasksLinesAndCommandsInOrder() {
        let results = search.results(for: "lis")
        #expect(results.map(\.group) == [.pages, .tasks, .lines])
        #expect(results[0].action == .go(.page(lisbon)))
        #expect(results[1].action == .openTask(flights))
        #expect(results[2].title == "Pack for Lisbon rain")
    }

    @Test func angleBracketListsOnlyCommands() {
        let results = search.results(for: "> today")
        #expect(results.map(\.title) == ["Go to Today"])
        #expect(search.results(for: ">").count == CommandSearch.commands.count)
    }

    @Test func everyWordMustMatch() {
        #expect(CommandSearch.matches("Book the Lisbon flights", "lis book"))
        #expect(!CommandSearch.matches("Book the Lisbon flights", "lis train"))
    }

    @Test func emptyQueryShowsPagesThenCommands() {
        let results = search.results(for: "")
        #expect(results.first?.group == .pages)
        #expect(results.last?.group == .commands)
    }
}

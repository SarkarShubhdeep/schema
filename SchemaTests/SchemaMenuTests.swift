//
//  SchemaMenuTests.swift
//  SchemaTests
//
//  Schema's own menus (#83): building them, and moving through them with
//  the keyboard.
//

import Foundation
import Testing
@testable import Schema

struct SchemaMenuTests {
    @SchemaMenuBuilder
    private func pageMenu(hasPage: Bool) -> [SchemaMenuItem] {
        SchemaMenuItem.divider
        if hasPage { SchemaMenuItem.header("Ideas") }
        SchemaMenuItem.action("Rename") {}
        SchemaMenuItem.action("Copy as Markdown", shortcut: "⇧⌘C") {}
        SchemaMenuItem.divider
        SchemaMenuItem.divider
        SchemaMenuItem.action("Export", isDisabled: true) {}
        for title in ["Work", "Groceries"] { SchemaMenuItem.action(title) {} }
        SchemaMenuItem.divider
        SchemaMenuItem.action("Delete page…", isDestructive: true) {}
        SchemaMenuItem.divider
    }

    private var titles: [String] { pageMenu(hasPage: true).map { $0.title.isEmpty ? "—" : $0.title } }

    @Test func dividersOnlySitBetweenGroups() {
        #expect(titles == ["Ideas", "Rename", "Copy as Markdown", "—", "Export", "Work", "Groceries", "—", "Delete page…"])
    }

    @Test func arrowsSkipHeadersDividersAndDisabledRowsAndWrap() {
        var nav = SchemaMenuNavigator(items: pageMenu(hasPage: true))
        nav.moveDown()
        #expect(nav.selectedItem?.title == "Rename")
        nav.moveDown(); nav.moveDown()
        #expect(nav.selectedItem?.title == "Work")
        nav.moveDown(); nav.moveDown()
        #expect(nav.selectedItem?.title == "Delete page…")
        nav.moveDown()
        #expect(nav.selectedItem?.title == "Rename")
        nav.moveUp()
        #expect(nav.selectedItem?.title == "Delete page…")
    }

    @Test func upFirstSelectsTheLastRow() {
        var nav = SchemaMenuNavigator(items: pageMenu(hasPage: false))
        nav.moveUp()
        #expect(nav.selectedItem?.title == "Delete page…")
    }

    @Test func typingJumpsToAMatchingRow() {
        var nav = SchemaMenuNavigator(items: pageMenu(hasPage: true))
        let now = Date()
        nav.type("g", at: now)
        #expect(nav.selectedItem?.title == "Groceries")
        nav.type("d", at: now.addingTimeInterval(2))
        #expect(nav.selectedItem?.title == "Delete page…")
        // Quick letters add up: "co" is Copy, not a second jump on "o".
        nav.type("c", at: now.addingTimeInterval(4))
        nav.type("o", at: now.addingTimeInterval(4.3))
        #expect(nav.selectedItem?.title == "Copy as Markdown")
        // A disabled row is never chosen.
        nav.type("e", at: now.addingTimeInterval(6))
        #expect(nav.selectedItem?.title != "Export")
    }

    @Test func aSubmenuWithNothingToChooseIsDisabled() {
        let empty = SchemaMenuItem.submenu("Move to") {}
        let full = SchemaMenuItem.submenu("Move to") { SchemaMenuItem.action("Work") {} }
        #expect(!empty.isChoosable)
        #expect(full.isChoosable)
        #expect(full.submenu?.count == 1)
    }
}

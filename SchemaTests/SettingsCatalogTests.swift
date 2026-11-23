//
//  SettingsCatalogTests.swift
//  SchemaTests
//
//  The Settings page (#108): every setting has one place, and search finds
//  settings by their words, across sections.
//

import Testing
@testable import Schema

struct SettingsCatalogTests {
    @Test func everySettingHasOnePlace() {
        let keys = SettingsCatalog.entries.map(\.key)
        #expect(Set(keys) == Set(SettingsKey.allCases))
        #expect(keys.count == SettingsKey.allCases.count)
    }

    @Test func sectionsListTheirCardsInOrder() {
        #expect(SettingsCatalog.groups(in: .general).map(\.group) == ["Tasks", "Calendar"])
        #expect(SettingsCatalog.groups(in: .quickNote).first?.entries.map(\.key) == [.quickNotePage, .quickNoteShortcut])
        #expect(SettingsCatalog.groups(in: .github).isEmpty)
    }

    @Test func searchFindsTitlesDescriptionsAndKeywords() {
        let keys = { (query: String) in SettingsCatalog.search(query).flatMap(\.entries).map(\.key) }
        #expect(keys("note") == [.quickNotePage, .quickNoteShortcut])
        #expect(keys("WEEK") == [.weekStart])
        #expect(keys("arrows") == [.replaceAsYouType])
        #expect(keys("quick short") == [.quickNoteShortcut])
        #expect(keys("rémind").contains(.notificationPermission))
        #expect(keys("").isEmpty)
        #expect(keys("zebra").isEmpty)
    }

    @Test func resultsNameTheirSection() {
        let groups = SettingsCatalog.search("note")
        #expect(groups.map(\.title) == ["Quick note › Quick note"])
    }

    @Test func theFirstWordIsHighlighted() {
        let title = "Quick note saves to"
        let range = SettingsCatalog.highlight(in: title, for: "NOTE saves")
        #expect(range.map { String(title[$0]) } == "note")
        #expect(SettingsCatalog.highlight(in: title, for: "  ") == nil)
    }
}

//
//  SnippetsTests.swift
//  SchemaTests
//
//  Snippets (#101): what can be saved, how they're stored, how Settings
//  lists them, and that the editor hears about changes once.
//

import Testing
@testable import Schema

struct SnippetsTests {
    private let email = Snippet(trigger: ";email", text: "name@example.com")

    @Test func triggersMustBeOneWordAndUnique() {
        #expect(SnippetRules.problem(trigger: "", text: "x", others: []) == .empty)
        #expect(SnippetRules.problem(trigger: ";my mail", text: "x", others: []) == .hasSpace)
        #expect(SnippetRules.problem(trigger: ";EMAIL", text: "x", others: [email]) == .taken)
        #expect(SnippetRules.problem(trigger: ";sig", text: "  \n", others: [email]) == .noText)
        #expect(SnippetRules.problem(trigger: ";sig", text: "— S.", others: [email]) == nil)
    }

    @Test func symbolTriggersFireAnywhere() {
        #expect(SnippetRules.startsWithSymbol(";email"))
        #expect(SnippetRules.startsWithSymbol("/date"))
        #expect(!SnippetRules.startsWithSymbol("sig"))
        #expect(!SnippetRules.startsWithSymbol(""))
    }

    @Test func storedAsJSONTheEditorReads() {
        let meet = Snippet(trigger: ";meet", text: "## Notes\n- [ ] Agenda")
        let json = SnippetStore.encode([email, meet])
        #expect(json.contains("\"trigger\":\";email\""))
        #expect(SnippetStore.decode(json) == [email, meet])
        #expect(SnippetStore.decode("not json").isEmpty)
    }

    @Test func previewsShowTheFirstLine() {
        #expect(email.preview == "name@example.com")
        #expect(Snippet(trigger: ";meet", text: "## Notes\n- [ ] Agenda\n- [ ] Actions").preview == "## Notes · 3 lines")
    }

    @Test func settingsSearchFindsSnippets() {
        let keys = SettingsCatalog.search("snippet").flatMap(\.entries).map(\.key)
        #expect(keys == [.snippets])
        #expect(SettingsCatalog.search("text replacement").flatMap(\.entries).map(\.key) == [.snippets])
        #expect(SettingsCatalog.groups(in: .editor).map(\.group) == ["Writing", "Snippets"])
    }
}

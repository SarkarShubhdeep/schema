//
//  Snippets.swift
//  Schema
//
//  Your own snippets (#101): a trigger, like ;email, and the text it turns
//  into in the editor. Stored with the settings on this Mac as JSON, which
//  the editor reads as is (snippets.js).
//

import Foundation

struct Snippet: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var trigger: String
    var text: String

    /// One line for the Settings list: the first line, and how many there are.
    var preview: String {
        let lines = text.components(separatedBy: "\n")
        let first = lines.first ?? ""
        return lines.count > 1 ? "\(first) · \(lines.count) lines" : first
    }
}

enum SnippetRules {
    enum Problem: Equatable {
        case empty
        case hasSpace
        case taken
        case noText

        var message: String {
            switch self {
            case .empty: "Type a trigger."
            case .hasSpace: "A trigger can't have spaces."
            case .taken: "Another snippet uses this trigger."
            case .noText: "Type the text it turns into."
            }
        }
    }

    /// What stops a snippet from being saved, if anything.
    static func problem(trigger: String, text: String, others: [Snippet]) -> Problem? {
        if trigger.isEmpty { return .empty }
        if trigger.contains(where: \.isWhitespace) { return .hasSpace }
        if others.contains(where: { $0.trigger.caseInsensitiveCompare(trigger) == .orderedSame }) { return .taken }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .noText }
        return nil
    }

    /// A trigger that's a plain word only fires on its own, never inside a
    /// longer word; a symbol first (;email) makes it fire anywhere.
    static func startsWithSymbol(_ trigger: String) -> Bool {
        guard let first = trigger.unicodeScalars.first else { return false }
        return !CharacterSet.alphanumerics.contains(first)
    }
}

enum SnippetStore {
    static func decode(_ json: String) -> [Snippet] {
        (try? JSONDecoder().decode([Snippet].self, from: Data(json.utf8))) ?? []
    }

    static func encode(_ snippets: [Snippet]) -> String {
        guard let data = try? JSONEncoder().encode(snippets) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}

//
//  SettingsCatalog.swift
//  Schema
//
//  Every setting Schema has, where it lives on the Settings page, and how
//  search finds it (#108). The page draws each one's control; this file only
//  knows names, so search can be tested without any views.
//

import Foundation

/// A page of the Settings sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, editor, quickNote, tasks, notifications, github, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .editor: "Editor"
        case .quickNote: "Quick note"
        case .tasks: "Tasks & routines"
        case .notifications: "Notifications"
        case .github: "GitHub"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .editor: "text.cursor"
        case .quickNote: "square.and.pencil"
        case .tasks: "repeat"
        case .notifications: "bell"
        case .github: "arrow.triangle.branch"
        case .about: "info.circle"
        }
    }

    /// GitHub settings arrive with the GitHub inbox in v0.6.
    var comingIn: String? { self == .github ? "v0.6" : nil }
}

/// Which setting a row is; the page draws its control.
enum SettingsKey: String, CaseIterable {
    case defaultList, weekStart
    case replaceAsYouType
    case quickNotePage, quickNoteShortcut
    case followerRoutines
    case notificationPermission
    case version
}

struct SettingsEntry: Identifiable, Equatable {
    let key: SettingsKey
    let section: SettingsSection
    /// The card it sits in on its section's page.
    let group: String
    let title: String
    let detail: String
    /// Other words people might search for.
    var keywords: [String] = []

    var id: SettingsKey { key }
}

/// Settings found by a search, in one card.
struct SettingsResultGroup: Identifiable, Equatable {
    let section: SettingsSection
    let group: String
    let entries: [SettingsEntry]

    var id: String { section.rawValue + "/" + group }
    var title: String { section.title + " › " + group }
}

enum SettingsCatalog {
    static let entries: [SettingsEntry] = [
        SettingsEntry(key: .defaultList, section: .general, group: "Tasks",
                      title: "New tasks from Everything go to",
                      detail: "The to-do list that gets tasks you add on Everything.",
                      keywords: ["default list", "default page", "inbox"]),
        SettingsEntry(key: .weekStart, section: .general, group: "Calendar",
                      title: "Week starts on",
                      detail: "Used for This week and Later this week.",
                      keywords: ["monday", "sunday", "calendar"]),
        SettingsEntry(key: .replaceAsYouType, section: .editor, group: "Writing",
                      title: "Replace as you type",
                      detail: "Turns -> into →, != into ≠ and three dots into …, and curls quotes. Backspace or ⌘Z right after keeps what you typed.",
                      keywords: ["arrows", "ligatures", "typography", "quotes", "smart"]),
        SettingsEntry(key: .quickNotePage, section: .quickNote, group: "Quick note",
                      title: "Quick note saves to",
                      detail: "Notes go to the top of this scratchpad under today's date.",
                      keywords: ["scratchpad", "capture"]),
        SettingsEntry(key: .quickNoteShortcut, section: .quickNote, group: "Quick note",
                      title: "Quick note shortcut",
                      detail: "Press it in any app to write a note.",
                      keywords: ["hotkey", "keyboard", "global"]),
        SettingsEntry(key: .followerRoutines, section: .tasks, group: "Routines",
                      title: "Complete follower routines independently",
                      detail: "Tick later steps of a routine before earlier ones.",
                      keywords: ["sequence", "after", "order"]),
        SettingsEntry(key: .notificationPermission, section: .notifications, group: "Notifications",
                      title: "Notification permission",
                      detail: "Reminders and Pomodoro use notifications.",
                      keywords: ["alerts", "reminders", "allow"]),
        SettingsEntry(key: .version, section: .about, group: "Schema",
                      title: "Version",
                      detail: "",
                      keywords: ["build", "about"]),
    ]

    /// A section's settings, card by card, in order.
    static func groups(in section: SettingsSection) -> [SettingsResultGroup] {
        grouped(entries.filter { $0.section == section })
    }

    /// Settings whose title, description, section, card or keywords contain
    /// every word typed, ignoring case and accents.
    static func search(_ query: String) -> [SettingsResultGroup] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        return grouped(entries.filter { entry in
            let haystack = ([entry.title, entry.detail, entry.section.title, entry.group] + entry.keywords).joined(separator: " ")
            return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        })
    }

    /// Where `query`'s first word sits in `title`, to highlight it.
    static func highlight(in title: String, for query: String) -> Range<String.Index>? {
        guard let word = query.split(whereSeparator: \.isWhitespace).first else { return nil }
        return title.range(of: String(word), options: [.caseInsensitive, .diacriticInsensitive])
    }

    private static func grouped(_ entries: [SettingsEntry]) -> [SettingsResultGroup] {
        var order: [String] = []
        var byGroup: [String: (SettingsSection, String, [SettingsEntry])] = [:]
        for entry in entries {
            let id = entry.section.rawValue + "/" + entry.group
            if byGroup[id] == nil {
                order.append(id)
                byGroup[id] = (entry.section, entry.group, [])
            }
            byGroup[id]?.2.append(entry)
        }
        return order.compactMap { id in
            byGroup[id].map { SettingsResultGroup(section: $0.0, group: $0.1, entries: $0.2) }
        }
    }
}

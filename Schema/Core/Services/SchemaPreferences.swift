//
//  SchemaPreferences.swift
//  Schema
//

import Foundation

enum SchemaPreferences {
    private enum Key {
        static let sortOption = "schema.preferences.sortOption"
        static let filterOption = "schema.preferences.filterOption"
        static let defaultWritableListID = "schema.preferences.defaultWritableListID"
        static let allowIndependentFollowerRoutineCompletion = "schema.preferences.allowIndependentFollowerRoutineCompletion"
        static let isSidebarCollapsed = "schema.preferences.isSidebarCollapsed"
        static let isDetailsPanelCollapsed = "schema.preferences.isDetailsPanelCollapsed"
        static let weekStart = "schema.preferences.weekStart"
        static let quickNotePageID = "schema.preferences.quickNotePageID"
    }

    /// Replacing -> with →, ... with … and so on in the editor (#99). On by default.
    static let replacesAsYouTypeKey = "schema.preferences.replacesAsYouType"
    /// Your snippets (#101), as JSON (see SnippetStore).
    static let snippetsKey = "schema.preferences.snippets"

    #if DEBUG
    static let defaults: UserDefaults = DemoData.isEnabled ? DemoData.defaults : .standard
    #else
    static let defaults = UserDefaults.standard
    #endif

    static var sortOption: TaskSortOption {
        get {
            guard let rawValue = defaults.string(forKey: Key.sortOption),
                  let option = TaskSortOption(rawValue: rawValue) else {
                return .manual
            }
            return option
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.sortOption)
        }
    }

    static var filterOption: TaskFilterOption {
        get {
            guard let rawValue = defaults.string(forKey: Key.filterOption),
                  let option = TaskFilterOption(rawValue: rawValue) else {
                return .all
            }
            return option
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.filterOption)
        }
    }

    static var defaultWritableListID: UUID? {
        get {
            guard let rawValue = defaults.string(forKey: Key.defaultWritableListID) else {
                return nil
            }
            return UUID(uuidString: rawValue)
        }
        set {
            if let newValue {
                defaults.set(newValue.uuidString, forKey: Key.defaultWritableListID)
            } else {
                defaults.removeObject(forKey: Key.defaultWritableListID)
            }
        }
    }

    static var allowIndependentFollowerRoutineCompletion: Bool {
        get {
            defaults.bool(forKey: Key.allowIndependentFollowerRoutineCompletion)
        }
        set {
            defaults.set(newValue, forKey: Key.allowIndependentFollowerRoutineCompletion)
        }
    }

    static var isSidebarCollapsed: Bool {
        get { defaults.bool(forKey: Key.isSidebarCollapsed) }
        set { defaults.set(newValue, forKey: Key.isSidebarCollapsed) }
    }

    static var isDetailsPanelCollapsed: Bool {
        get { defaults.bool(forKey: Key.isDetailsPanelCollapsed) }
        set { defaults.set(newValue, forKey: Key.isDetailsPanelCollapsed) }
    }

    /// The scratchpad Quick note (⌃⌥N) saves into; nil means the first scratchpad.
    static var quickNotePageID: UUID? {
        get { defaults.string(forKey: Key.quickNotePageID).flatMap(UUID.init(uuidString:)) }
        set {
            if let newValue {
                defaults.set(newValue.uuidString, forKey: Key.quickNotePageID)
            } else {
                defaults.removeObject(forKey: Key.quickNotePageID)
            }
        }
    }

    /// First day of the week for the week chart and "Later this week". Monday unless changed.
    static var weekStart: WeekStart {
        get { defaults.string(forKey: Key.weekStart).flatMap(WeekStart.init(rawValue:)) ?? .monday }
        set { defaults.set(newValue.rawValue, forKey: Key.weekStart) }
    }
}

enum WeekStart: String, CaseIterable, Identifiable {
    case monday
    case sunday

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monday: "Monday"
        case .sunday: "Sunday"
        }
    }

    /// `Calendar.firstWeekday` value (1 = Sunday, 2 = Monday).
    var firstWeekday: Int {
        switch self {
        case .monday: 2
        case .sunday: 1
        }
    }
}

extension Calendar {
    /// The user's calendar with Schema's week start applied.
    static func schema(weekStart: WeekStart = SchemaPreferences.weekStart) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStart.firstWeekday
        return calendar
    }
}

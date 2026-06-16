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
    }

    private static let defaults = UserDefaults.standard

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
}

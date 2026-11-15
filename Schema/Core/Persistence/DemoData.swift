//
//  DemoData.swift
//  Schema
//
//  Debug-only sample data for screenshots and demos. Launch with the
//  `-SchemaDemoData` argument: the app then uses an in-memory store filled
//  with sample lists and tasks, its own preferences, and no notifications,
//  so nothing from the real store or the real notification center shows up.
//

#if DEBUG
import Foundation
import SwiftData

enum DemoData {
    static let launchArgument = "-SchemaDemoData"

    static let isEnabled = CommandLine.arguments.contains(launchArgument)

    /// `-SchemaDemoDark` forces dark mode for screenshots.
    static let forcesDarkAppearance = CommandLine.arguments.contains("-SchemaDemoDark")

    /// Separate preferences so demo runs never change the real ones.
    static let defaults: UserDefaults = {
        let suite = "com.sarkarshubhdeep.schema.demo"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }()

    @MainActor
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaMigrationV4.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        seed(container.mainContext)
        return container
    }

    @MainActor
    private static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let everything = SchemaList(title: SchemaList.everythingTitle, order: 0, accentColorName: SchemaListColorName.neutral.rawValue)
        let daily = SchemaList(title: "Daily Todos", order: 1, accentColorName: SchemaListColorName.grey.rawValue, tagLabel: "Daily")
        let work = SchemaList(title: "Work", order: 2, accentColorName: SchemaListColorName.blue.rawValue, tagLabel: "Work")
        let groceries = SchemaList(title: "Groceries", order: 3, accentColorName: SchemaListColorName.purple.rawValue, tagLabel: "Groceries")
        let reading = SchemaList(title: "Reading", order: 4, accentColorName: SchemaListColorName.green.rawValue, tagLabel: "Reading")
        [everything, daily, work, groceries, reading].forEach(context.insert)

        var index = 0.0
        func add(_ title: String, to list: SchemaList, note: String? = nil, reminder: Date? = nil, done: Bool = false) {
            index += 1
            let task = SchemaTask(title: title, description: note, list: list, reminderTime: reminder)
            task.manualSortIndex = index
            task.isCompleted = done
            context.insert(task)
        }

        add("Reply to Maya about the onboarding copy", to: daily)
        add("Call the landlord about the heater", to: daily, note: "Radiator in the bedroom makes noise after 10 PM.", reminder: at(0, 18))
        add("Pick up dry cleaning", to: daily, reminder: at(0, 17))
        add("Renew passport photos", to: daily, reminder: at(3, 10))
        add("Book dentist appointment", to: daily, done: true)

        add("Review PR #42 for the sync service", to: work, note: "Check the retry logic before Friday’s release.", reminder: at(0, 15))
        add("Fix flaky snapshot test in TaskListView", to: work)
        add("Write standup notes", to: work, reminder: at(1, 9, 30))
        add("Triage TestFlight feedback", to: work)
        add("Update the onboarding checklist", to: work, done: true)

        add("Oat milk, coffee beans, lemons", to: groceries, reminder: at(0, 17, 30))
        add("Sourdough and eggs", to: groceries)

        add("Finish chapter 4 of The Design of Everyday Things", to: reading)
        add("Read the SwiftData migration guide", to: reading, done: true)

        try? context.save()
        defaults.set(daily.id.uuidString, forKey: "schema.preferences.defaultWritableListID")
    }
}
#endif

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
    /// `-SchemaDemoLight` forces light mode, whatever the system uses.
    static let forcesLightAppearance = CommandLine.arguments.contains("-SchemaDemoLight")

    /// `-SchemaDemoToday` opens on the Today view.
    static let opensToday = CommandLine.arguments.contains("-SchemaDemoToday")
    /// `-SchemaDemoUpcoming` opens on the Upcoming view.
    static let opensUpcoming = CommandLine.arguments.contains("-SchemaDemoUpcoming")
    /// `-SchemaDemoSettings` opens Settings.
    static let opensSettings = CommandLine.arguments.contains("-SchemaDemoSettings")

    /// `-SchemaDemoNewPage` opens the New page dialog with Scratchpad picked.
    static let opensNewPage = CommandLine.arguments.contains("-SchemaDemoNewPage")
    /// `-SchemaDemoScratchpad` opens the Ideas scratchpad.
    static let opensScratchpad = CommandLine.arguments.contains("-SchemaDemoScratchpad")

    /// `-SchemaDemoSlash` also opens the / menu on a new line in Ideas.
    static let opensSlashMenu = CommandLine.arguments.contains("-SchemaDemoSlash")

    /// `-SchemaDemoMakeTask` puts the caret on an open to-do in Ideas, showing "Make task in …".
    static let focusesOpenToDo = CommandLine.arguments.contains("-SchemaDemoMakeTask")

    /// `-SchemaDemoRoutine` opens an open routine task as a page.
    static let opensRoutineTask = CommandLine.arguments.contains("-SchemaDemoRoutine")

    /// `-SchemaDemoQuickNote` opens the Quick note panel with some text.
    static let opensQuickNote = CommandLine.arguments.contains("-SchemaDemoQuickNote")
    /// `-SchemaDemoDeletePage` asks to delete the first page (#42).
    static let opensPageDelete = CommandLine.arguments.contains("-SchemaDemoDeletePage")
    /// `-SchemaDemoRenamePage` starts renaming the selected page (#42).
    static let renamesPage = CommandLine.arguments.contains("-SchemaDemoRenamePage")
    /// `-SchemaDemoToggleSidebar` collapses (or expands) the sidebar 3 seconds
    /// after launch, to film the motion (#44). Pair with `-SchemaDemoSlowMotion`.
    static let togglesSidebar = CommandLine.arguments.contains("-SchemaDemoToggleSidebar")
    /// `-SchemaDemoLarge` adds a 1,000-task to-do list and a 500-block
    /// scratchpad, for the performance pass (#45).
    static let seedsLargePages = CommandLine.arguments.contains("-SchemaDemoLarge")
    /// `-SchemaDemoBenchmark` (with `-SchemaDemoLarge`) switches between the
    /// large pages and edits a block, printing how long each step takes.
    static let runsBenchmark = CommandLine.arguments.contains("-SchemaDemoBenchmark")
    /// `-SchemaEditorFeelCheck` shows a scratchpad in the current editor and
    /// in TipTap side by side (#76). TipTap's edits are not saved. Works with
    /// or without the demo data.
    static let showsEditorFeelCheck = CommandLine.arguments.contains("-SchemaEditorFeelCheck")
    /// Shows the first page mid-drag, two and a half rows down (#42).
    static let dragsPage = CommandLine.arguments.contains("-SchemaDemoDragPage")

    /// `-SchemaDemoPage` opens on the first page (Daily Todos).
    static let opensFirstPage = CommandLine.arguments.contains("-SchemaDemoPage")

    /// `-SchemaDemoSelect` starts with two tasks selected; `-SchemaDemoDelete`
    /// also opens the delete dialog for them.
    static let selectsTasks = CommandLine.arguments.contains("-SchemaDemoSelect")
    static let opensDeleteDialog = CommandLine.arguments.contains("-SchemaDemoDelete")
    /// `-SchemaDemoDetail` opens the first task with notes in the details panel.
    static let opensTaskDetail = CommandLine.arguments.contains("-SchemaDemoDetail")

    /// Window width for screenshots: 1280 by default, `-SchemaDemoMedium` 1100,
    /// `-SchemaDemoNarrow` 880 (to show auto-collapse).
    static let windowWidth: CGFloat = {
        if CommandLine.arguments.contains("-SchemaDemoNarrow") { return 880 }
        if CommandLine.arguments.contains("-SchemaDemoMedium") { return 1100 }
        if CommandLine.arguments.contains("-SchemaDemoWide") { return 1440 }
        return 1280
    }()

    /// Separate preferences so demo runs never change the real ones.
    static let defaults: UserDefaults = {
        let suite = "com.sarkarshubhdeep.schema.demo"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        if CommandLine.arguments.contains("-SchemaDemoCollapsed") {
            // Start with both side panels collapsed, for screenshots.
            defaults.set(true, forKey: "schema.preferences.isSidebarCollapsed")
            defaults.set(true, forKey: "schema.preferences.isDetailsPanelCollapsed")
        }
        return defaults
    }()

    @MainActor
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaCurrentVersion.self)
        // The large pages go in a throwaway file on disk, like the real store,
        // so the performance numbers match the app (#45).
        let configuration: ModelConfiguration
        if seedsLargePages {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("schema-demo-large-\(UUID().uuidString).store")
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        seed(container.mainContext)
        return container
    }

    @MainActor
    private static func seedLargePages(_ context: ModelContext, startingAt start: Double) {
        let backlog = SchemaList(title: "Backlog", order: 6, accentColorName: SchemaListColorName.blue.rawValue, tagLabel: "Backlog")
        let journal = SchemaList(title: "Journal", order: 7, accentColorName: SchemaListColorName.neutral.rawValue, kind: .scratchpad)
        context.insert(backlog)
        context.insert(journal)
        let calendar = Calendar.current
        for n in 0..<1000 {
            let reminder = n % 7 == 0 ? calendar.date(byAdding: .hour, value: n % 200, to: .now) : nil
            let task = SchemaTask(title: "Backlog item \(n + 1): tidy up the \(["settings", "sync", "sidebar", "export", "search"][n % 5]) code", list: backlog, reminderTime: reminder)
            task.manualSortIndex = start + Double(n)
            if n % 4 == 0 { task.setCompleted(true) }
            context.insert(task)
        }
        let kinds: [BlockKind] = [.text, .bullet, .bullet, .todo, .heading, .text, .quote, .todo]
        for n in 0..<500 {
            let kind = kinds[n % kinds.count]
            let text = kind == .heading
                ? "Week \(n / 8 + 1)"
                : "Line \(n + 1). Notes on what went well, what didn’t, and what to try next time around."
            context.insert(SchemaBlock(kind: kind, text: text, sortIndex: Double(n + 1), page: journal))
        }
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
        let ideas = SchemaList(title: "Ideas", order: 5, accentColorName: SchemaListColorName.neutral.rawValue, kind: .scratchpad)
        [everything, daily, work, groceries, reading, ideas].forEach(context.insert)

        var index = 0.0
        func add(_ title: String, to list: SchemaList, note: String? = nil, reminder: Date? = nil, done: Bool = false) {
            index += 1
            let task = SchemaTask(title: title, description: note, list: list, reminderTime: reminder)
            task.manualSortIndex = index
            if done { task.setCompleted(true) }
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

        // Daily routines: one done today, one still open this evening.
        let stretch = SchemaTask(title: "Morning stretch", list: daily, reminderTime: at(0, 7, 30), isRoutine: true)
        stretch.manualSortIndex = index + 1
        stretch.setCompleted(true)
        context.insert(stretch)
        let plan = SchemaTask(title: "Plan tomorrow’s top three", list: daily, reminderTime: at(0, 21, 30), isRoutine: true)
        plan.manualSortIndex = index + 2
        context.insert(plan)

        // The Ideas scratchpad, as on the canvas.
        let ideaBlocks: [(BlockKind, String, Bool)] = [
            (.text, "Schema keeps turning into more than a to-do app. Pages could be the core idea: every page has a type, and the type decides its structure.", false),
            (.bullet, "To-do list: what we have today", false),
            (.bullet, "Scratchpad: this page, free-form", false),
            (.bullet, "Later: table, board, calendar", false),
            (.todo, "Sketch the quick note panel", false),
            (.todo, "Decide whether page type can change after creation", false),
            (.heading, "Questions", false),
            (.quote, "Should quick notes land at the top of Ideas, or in a daily note?", false),
            (.divider, "", false),
            (.text, "GitHub inbox: summarize review requests every morning and pin them to Today.", false),
        ]
        for (offset, item) in ideaBlocks.enumerated() {
            let block = SchemaBlock(kind: item.0, text: item.1, sortIndex: Double(offset + 1), page: ideas)
            block.isChecked = item.2
            context.insert(block)
            // As on the canvas, this line was already made into a task in Work.
            if item.1 == "Sketch the quick note panel" {
                let task = SchemaTask(title: item.1, list: work)
                index += 1
                task.manualSortIndex = index
                context.insert(task)
                block.linkedTaskID = task.id
            }
        }

        // A task page body, as on the canvas (#31).
        if let landlord = try? context.fetch(FetchDescriptor<SchemaTask>()).first(where: { $0.title.hasPrefix("Call the landlord") }) {
            let body: [(BlockKind, String, Bool)] = [
                (.text, "Radiator in the bedroom makes noise after 10 PM.", false),
                (.heading, "Before calling", false),
                (.todo, "Find the lease renewal date", true),
                (.todo, "Record the noise around 10 PM", false),
                (.todo, "Photos of the radiator valve", false),
                (.heading, "Ask about", false),
                (.bullet, "A replacement valve or bleeding the radiator", false),
                (.bullet, "Whether someone can come this week", false),
            ]
            for (offset, item) in body.enumerated() {
                let block = SchemaBlock(kind: item.0, text: item.1, sortIndex: Double(offset + 1), task: landlord)
                block.isChecked = item.2
                context.insert(block)
            }
            landlord.taskDescription = nil
        }

        if seedsLargePages {
            seedLargePages(context, startingAt: index + 10)
        }

        try? context.save()
        defaults.set(daily.id.uuidString, forKey: "schema.preferences.defaultWritableListID")
    }
}
#endif

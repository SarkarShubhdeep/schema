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
    /// `-SchemaDemoSidebarSection pinned` opens that sidebar section (#120).
    static let sidebarSection = value(after: "-SchemaDemoSidebarSection").flatMap(SidebarSection.init(rawValue:))
    /// `-SchemaDemoNoPins` starts with nothing pinned.
    static let hasNoPins = CommandLine.arguments.contains("-SchemaDemoNoPins")
    /// `-SchemaDemoScrollBars` keeps the themed scroll bars showing (#121).
    static let showsScrollBars = CommandLine.arguments.contains("-SchemaDemoScrollBars")
    /// `-SchemaDemoCommandBar lis` opens ⌘K with that typed (#122).
    static let commandBarQuery = value(after: "-SchemaDemoCommandBar")
    /// `-SchemaDemoSettings` opens Settings.
    static let opensSettings = CommandLine.arguments.contains("-SchemaDemoSettings")

    /// `-SchemaDemoNewPage` opens the New page dialog with Scratchpad picked.
    static let opensNewPage = CommandLine.arguments.contains("-SchemaDemoNewPage")
    /// `-SchemaDemoScratchpad` opens the Ideas scratchpad.
    static let opensScratchpad = CommandLine.arguments.contains("-SchemaDemoScratchpad")
    /// `-SchemaDemoTagPage` opens the #chores tag page (#102).
    static let opensTagPage = CommandLine.arguments.contains("-SchemaDemoTagPage")
    /// `-SchemaDemoTagFlat`: #chores with Group by page off.
    static let tagPageIsFlat = CommandLine.arguments.contains("-SchemaDemoTagFlat")
    /// Opens the Pomodoro page (#89).
    static let opensPomodoro = CommandLine.arguments.contains("-SchemaDemoPomodoro")
    /// Scrolls the Pomodoro page to its focus history, for screenshots.
    static let showsPomodoroHistory = CommandLine.arguments.contains("-SchemaDemoPomodoroHistory")
    /// Opens the focus history on Year.
    static let showsPomodoroYear = CommandLine.arguments.contains("-SchemaDemoPomodoroYear")
    /// `-SchemaDemoMakeTask` puts the caret in the first open to-do, so its
    /// Make task badge shows (#80); `-SchemaDemoTaskMenu` also right-clicks it.
    static let showsMakeTask = CommandLine.arguments.contains("-SchemaDemoMakeTask")
    static let opensTaskMenu = CommandLine.arguments.contains("-SchemaDemoTaskMenu")
    /// `-SchemaDemoMenu <label>` opens the Schema menu (#83) with that
    /// accessibility label; `-SchemaDemoMenuKeys down,down,right` then
    /// presses keys in it, and `-SchemaDemoMenuClick <row>` clicks a row.
    static let opensMenu = value(after: "-SchemaDemoMenu")
    /// Settings page (#108): `-SchemaDemoSettingsSection editor`, `-SchemaDemoSettingsSearch note`.
    static let settingsSection = value(after: "-SchemaDemoSettingsSection").flatMap(SettingsSection.init(rawValue:))
    static let settingsQuery = value(after: "-SchemaDemoSettingsSearch")
    /// Opens New snippet in Settings › Editor (#101).
    static let opensNewSnippet = CommandLine.arguments.contains("-SchemaDemoNewSnippet")
    static let menuKeys = value(after: "-SchemaDemoMenuKeys")?.split(separator: ",").map(String.init) ?? []
    static let menuClick = value(after: "-SchemaDemoMenuClick").flatMap { Int($0) }
    /// `-SchemaDemoRightClick 0.1,0.4` right-clicks at that spot of the
    /// window (fractions of its width and height from the top left).
    static let rightClickSpot: CGPoint? = value(after: "-SchemaDemoRightClick").flatMap { text in
        let parts = text.split(separator: ",").compactMap { Double($0) }
        return parts.count == 2 ? CGPoint(x: parts[0], y: parts[1]) : nil
    }
    /// `-SchemaDemoNewTimer` opens New timer on the Pomodoro page.
    static let opensNewTimer = CommandLine.arguments.contains("-SchemaDemoNewTimer")

    private static func value(after flag: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: flag), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `-SchemaDemoMention` types two @ mentions at the end of the page and
    /// leaves the @ menu open on the second (#81).
    static let typesMention = CommandLine.arguments.contains("-SchemaDemoMention")
    /// `-SchemaDemoLinkedMenu` right-clicks the first to-do already made into a task.
    static let opensLinkedTaskMenu = CommandLine.arguments.contains("-SchemaDemoLinkedMenu")

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
    /// large pages, printing how long each step takes.
    static let runsBenchmark = CommandLine.arguments.contains("-SchemaDemoBenchmark")
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
        // Upcoming and the Ideas page pinned (#120), unless asked not to.
        if !CommandLine.arguments.contains("-SchemaDemoNoPins") {
            defaults.set(["view:upcoming"], forKey: "schema.preferences.pinned")
        }
        // A few snippets (#101), so Settings and the editor have some to show.
        defaults.set(SnippetStore.encode([
            Snippet(trigger: ";email", text: "name@example.com"),
            Snippet(trigger: ";meet", text: "## Meeting notes {date}\n- [ ] Agenda\n- [ ] Decisions\n- [ ] Actions\n{cursor}"),
            Snippet(trigger: ";shrug", text: "¯\\_(ツ)_/¯"),
        ]), forKey: SchemaPreferences.snippetsKey)
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

        // The lines above are written as v0.5 blocks, then moved into
        // documents exactly as the V7 migration does (#77).
        try? PageDocumentMigration.moveBlocksIntoDocuments(in: context)
        seedTags(context, ideas: ideas, daily: daily, order: 6, index: index + 20)
        seedPomodoro(context, readingPageID: reading.id)
        try? context.save()
        defaults.set(daily.id.uuidString, forKey: "schema.preferences.defaultWritableListID")
    }

    /// #chores and #weekend (#102), as on the Tag page board: a few tagged
    /// lines at the end of Ideas, a task tagged in its title, and the
    /// #chores page with a line of its own.
    private static func seedTags(_ context: ModelContext, ideas: SchemaList, daily: SchemaList, order: Int, index: Double) {
        let chores = SchemaList(title: "chores", order: order, kind: .tag)
        let weekend = SchemaList(title: "weekend", order: order + 1, kind: .tag)
        [chores, weekend].forEach(context.insert)
        func chip(_ tag: SchemaList) -> [String: Any] {
            ["type": "mention", "attrs": ["kind": "tag", "id": tag.id.uuidString, "label": tag.title]]
        }
        func text(_ value: String) -> [String: Any] { ["type": "text", "text": value] }
        func paragraph(_ content: [[String: Any]]) -> [String: Any] { ["type": "paragraph", "content": content] }
        func todo(_ content: [[String: Any]], done: Bool = false) -> [String: Any] {
            ["type": "taskItem", "attrs": ["checked": done], "content": [paragraph(content)]]
        }

        if var doc = PageDocument.parse(ideas.documentJSON) {
            var content = doc["content"] as? [[String: Any]] ?? []
            content.append(["type": "heading", "attrs": ["level": 2], "content": [text("Around the flat")]])
            content.append(["type": "taskList", "content": [
                todo([text("Clean the kitchen island "), chip(chores)]),
                todo([text("Fix the porch light "), chip(chores), text(" "), chip(weekend)], done: true),
                todo([text("Sort the recycling before Thursday "), chip(chores)]),
            ]])
            content.append(["type": "bulletList", "content": [
                ["type": "listItem", "content": [paragraph([text("Ask who can lend a drill for the shelf "), chip(weekend)])]],
            ]])
            doc["content"] = content
            ideas.setDocument(TipTapDocument.json(doc))
        }
        chores.setDocument(TipTapDocument.json(["type": "doc", "content": [
            paragraph([text("Kitchen on Mondays, bathroom on Thursdays. Bins go out Wednesday night.")]),
        ]]))
        if tagPageIsFlat { defaults.set([chores.id.uuidString], forKey: "schema.preferences.ungroupedTagPages") }
        if seedsLargePages, let journal = try? context.fetch(FetchDescriptor<SchemaList>()).first(where: { $0.title == "Journal" }),
           var doc = PageDocument.parse(journal.documentJSON) {
            // #review on 100 to-dos at the end of Journal, for the long tag
            // page in the performance pass (#103).
            let review = SchemaList(title: "review", order: order + 2, kind: .tag)
            context.insert(review)
            var content = doc["content"] as? [[String: Any]] ?? []
            content.append(["type": "taskList", "content": (1...100).map { n in
                todo([text("Review point \(n): what to keep and what to drop "), chip(review)], done: n % 5 == 0)
            }])
            doc["content"] = content
            journal.setDocument(TipTapDocument.json(doc))
        }
        let bins = SchemaTask(title: "Take the bins out #chores", list: daily)
        bins.manualSortIndex = index
        context.insert(bins)
    }

    /// Three timers like the canvas (#89): one focusing, one on a break, one
    /// paused, with today's sessions, the past week and most of a year.
    private static func seedPomodoro(_ context: ModelContext, readingPageID: UUID) {
        let now = Date()
        let calendar = Calendar.current
        let editor = PomodoroTimer(name: "Schema editor", focusMinutes: 25, breakMinutes: 5, sortIndex: 1)
        editor.phase = .focus
        editor.phaseEndsAt = now.addingTimeInterval(18 * 60 + 42)
        editor.focusStartedAt = now.addingTimeInterval(-(6 * 60 + 18))
        let doc = PomodoroTimer(name: "Milestone doc", focusMinutes: 40, breakMinutes: 10, sortIndex: 2)
        doc.phase = .rest
        doc.phaseEndsAt = now.addingTimeInterval(6 * 60 + 15)
        let reading = PomodoroTimer(name: "Reading", focusMinutes: 50, breakMinutes: 10, sortIndex: 3)
        reading.phase = .focus
        reading.pausedRemaining = 31 * 60 + 8
        reading.focusStartedAt = now.addingTimeInterval(-(18 * 60 + 52))
        reading.linkedPageID = readingPageID
        let timers = [editor, doc, reading]
        timers.forEach(context.insert)

        func add(_ timer: PomodoroTimer, start: Date) {
            context.insert(PomodoroSession(
                timerID: timer.id, timerName: timer.name, startedAt: start,
                endedAt: start.addingTimeInterval(TimeInterval(timer.focusMinutes * 60)), minutes: timer.focusMinutes
            ))
        }
        // A day of sessions back to back from 9:00, with breaks between.
        func day(_ offset: Int, _ order: [PomodoroTimer]) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)),
                  var start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) else { return }
            for timer in order {
                add(timer, start: start)
                start = start.addingTimeInterval(TimeInterval((timer.focusMinutes + timer.breakMinutes) * 60))
            }
        }
        day(0, [editor, editor, doc, editor, reading, doc, editor])

        var seed: UInt64 = 7
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        for offset in 1..<300 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let weekend = calendar.isDateInWeekend(date)
            let count = weekend ? (random() > 0.7 ? Int(random() * 4) : 0) : (random() < 0.1 ? 0 : 3 + Int(random() * 10))
            day(offset, (0..<count).map { _ in timers[Int(random() * 2.6) % 3] })
        }
    }
}
#endif

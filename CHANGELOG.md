# Changelog

All notable changes to Schema are documented in this file.

## [Unreleased]

### Added

- Back and forward (#118). Every page's header starts with back and forward buttons, and Go › Back (⌘[) and Forward (⌘]) walk through the pages, views and tools you've opened, Settings included. The Go menu also opens Today, Upcoming, Everything and Pomodoro. Schema opens on Today. Deleting the page you're on goes back to where you were. On a task page, previous and next task moved to ⌥⌘↑ and ⌥⌘↓.

- A new sidebar (#120). Under the window controls: Search (⌘K) and a Today tile with the date, the next reminder and how many tasks are due (dark while Today is open). Then Pinned, Views (Upcoming, Everything), Pages, Tags and Tools as sections, one open at a time: click a header to open it; headers above it stay at the top, the rest move to the bottom, and the open one gets the room between and scrolls. Pages is one flat list. Right-click a page, view or Pomodoro to pin it: Pinned appears with it (drag to reorder), and the item keeps its place in its own section with a small pin. The sidebar remembers which section was open.

- Search everything with ⌘K (#122). One field finds pages and tags, tasks, and lines inside pages, plus commands such as New page, Go to Today, Open Settings and toggling the panels. Results are grouped; ↑ and ↓ move, Return opens, Esc closes. Typing > lists commands only, and ⌘⇧P opens it that way. The Search pill at the top of the sidebar opens it too.

- Writing on to-do lists (#123). A list can have writing above its tasks, in the same editor as notes: plans, context, links, checklists. It stays out of sight until you choose Add writing in the page's ⋯ menu (⌥⌘W), is only as tall as what you write, and scrolls with the list. Single-key shortcuts like N stay out of the way while you type there.

### Changed

- Themed scroll bars everywhere (#121). The system scroll bars are gone from pages, lists, the editor, the sidebar, the overview panel, Settings, Pomodoro and Notifications. In their place is a thin rounded thumb in the text colour at 16%, with no track, that shows while you scroll and fades away after, in light and dark, even with "Always show scroll bars" on.

- The window is laid out as floating islands on a 16/8 grid (#116). The sidebar, each page's header and the overview panel are rounded islands 16 pt from the window edges and 16 pt apart, with 8 pt padding and 8 pt corners inside, and 44 pt buttons in their header and footer rows. The window controls sit inside the sidebar's header row. Collapsed, the sidebar is a small pill with the window controls and its expand button (the floating bar of icons is gone), and the overview is its expand button alone. Every page puts where you are and its actions in a header island at the top: sort and page options, Hide done, Quick note, New timer, and previous and next on a task page. Page content is centred in a 600 pt column on every page, Settings included. Settings and Notifications moved to the sidebar's bottom row, and sidebar rows have 8 pt corners. The overview panel is only as tall as what it shows (it scrolls if that is taller than the window), and its cards sit flush with it, set apart by a faint tint instead of a white fill and border.

## [0.5.6] — 2026-11-23

Editor polish: #tags and tag pages with synced blocks, snippets, replace as you type, Backspace that brings markdown back, ⌘Return to tick, and Settings as its own page.

### Added

- Synced blocks on tag pages (#113). A tagged block now exists once and is editable everywhere it shows: on #chores, type in, tick or format a block that lives in Ideas, and Ideas (and every other tag page it's on) shows the change. Return makes a new line under it that is the tag page's own (made on #chores, it lives on #chores; tag it #idea and it shows on #idea "from #chores"); Backspace in an empty one, or Remove #tag in its ⋮⋮ menu, takes the tag off; Delete everywhere… removes it from every page. Hovering one shows where it lives; Open in … goes there. Every block now carries a lasting id so a synced block is found after its page changes (no schema change).
- #tags and tag pages (#102). Write #chores anywhere in a line, on a page, a task page or in Quick note: "#name" and a space becomes a tag chip (Backspace right after undoes it), and typing # opens a menu of your tags. The first #chores makes a #chores tag page, listed under Tags in the sidebar. A tag page is a page you can write on, and below that it shows every line tagged #chores on other pages, live, grouped by page: tick to-dos right there (their page and task follow), click a line to open it where it lives, or Hide done. Tasks with #chores in their title show up too. Renaming a tag page renames the tag everywhere; deleting it turns the tags back into plain words. Clicking a tag chip opens its page.
- Snippets (#101). In Settings › Editor, make your own snippets: a trigger like ;email and the text it turns into. Typing the trigger in a page, task page or Quick note replaces it as soon as it's complete; Backspace or ⌘Z right after brings the trigger back. Text can span lines and use markdown (a heading and to-dos, say), with {date}, {time} and {cursor} filled in when used. Plain-word triggers only fire on their own; ones starting with a symbol fire anywhere. Never inside code.
- Settings is its own page (#108). ⌘, or the gear opens Settings in the main window instead of a sheet, with its own sidebar: Back to Schema (Esc), a search field (⌘F), and sections for General, Editor, Quick note, Tasks & routines, Notifications and About (GitHub arrives in v0.6). Search looks through every setting's name and description and lists matches by section. Every setting works as before.
- Replace as you type (#99). In pages, task pages and Quick note, -> becomes →, <- ←, <-> ↔, => ⇒, <=> ⇔, != ≠, >= ≥, <= ≤, ... …, a--b a—b, +/- ±, (c) ©, (tm) ™, and quotes and apostrophes curl. Never inside code blocks or code, and --- at the start of a line still makes a divider. Backspace or ⌘Z right after keeps what you typed, and Settings › Editor › Replace as you type turns it off.

### Changed

- Backspace brings markdown back (#98). At the start of a heading, to-do, list item or quote, Backspace turns it into a plain line that starts with the markdown that made it (`## `, `[ ] `, `[x] `, `- `, `2. `, `> `), so you can edit it: type x between the brackets to tick a to-do, change `##` to `#`, or delete the markdown to keep a plain line. Moving off the line turns it back into a block, and a to-do made into a task keeps its task. ⌘Z right after puts the block back.
- ⌘Return in a to-do ticks it, or unticks it, instead of adding a line break (#97). With several to-dos selected it ticks them all (or unticks them if all were done), and a to-do made into a task ticks its task too. ⇧Return still adds a line break, ⌘Return elsewhere on a page works as before, and in Quick note it still saves as a task.

### Fixed

- Editing markdown that Backspace brought back (#98): Return on a line like [x] hello now makes it a ticked to-do and starts a new to-do under it, in the same list. The caret could show up at the far right after a to-do came back; the line now turns back in the same edit, so the caret is drawn once, where it is. A bullet coming back no longer merges into a numbered list next to it.
- Opening a tag page is faster with many tasks: tasks with the tag in their title are found in one pass, and a page is read once (#103). With 1,000 tasks and 100 tagged lines it opens in about 167 ms, from 223 ms.

### Development

- Debug builds are called "Schema Dev" and have their own icon, the Schema glyph in yellow on near-black, so they're easy to tell apart from the TestFlight app in the Dock and ⌘Tab. They also have their own bundle ID (com.sarkarshubhdeep.schema.dev), so they keep their own data and never open the TestFlight app's. Release and TestFlight builds are unchanged.

## [0.5.5] — 2026-11-21

The new editor everywhere, with Markdown, @ mentions, to-dos that become tasks, and Schema's own menus. Pages, task pages and Quick note all use it, and the old block editor is gone.

### Added

- Markdown in the new editor (#79). Typing # , - , 1. , [ ] , > , ``` or --- at the start of a line makes a heading, list, numbered list, to-do, quote, code block or divider, and **bold**, _italic_, `code` and ~~strikethrough~~ format as you type. Pasting Markdown keeps its headings, lists, to-dos, quotes, code and links; ⇧⌘V pastes plain text. Numbered lists are a new block kind in the / menu and Turn into. Copy as Markdown is in each block's handle menu and in the page menu (⇧⌘C), and Export as Markdown… saves the page as a .md file.

- To-dos and tasks in the new editor (#80). Hovering an open to-do, or writing in it, shows "Make task in …" on the right for your default page; right-click the to-do (or use Make task in from its handle) to pick another to-do page, or Change the default page… in Settings. A to-do made into a task shows "Task in …", which opens the task, and ticking either one ticks the other. Right-click a linked to-do to move its task to another to-do page (Move task to), or Unlink from task to keep both but stop them ticking together. "Make tasks from open to-dos" in the page menu works as before.

- @ mentions in the new editor (#81). Type @ for one menu: Today, Now and Tomorrow, then matching pages and open tasks. The choice becomes a grey chip with a small icon; clicking it opens the page, the task, or the day on Today or Upcoming. Renaming a page or task updates its chips, and search and Copy as Markdown read a chip as its name. A chip for something deleted is struck through.

- Quick note (⌃⌥N) uses the new editor (#82): markdown as you type, lists, to-dos and @ mentions, the same as on a page. Return still saves, ⇧Return starts a new line or list item, ⌘Return saves as a task and Esc closes. The note goes into the scratchpad with its formatting kept.

- Schema's own menus (#83). Every dropdown, ⋯ menu and right-click menu now has Schema's look, the same as the editor's: a surface panel with a hairline border and soft shadow, checks on the left, shortcuts and › on the right, and Delete in red at the end. That covers page options with Sort and Filter, the sidebar, tasks, the selection bar, the task page and its panel, Pomodoro, Quick note and Settings. ↑ ↓, Return, Esc, ← → for submenus and typing a name all work, and VoiceOver can open a right-click menu with its Show menu action. Right-clicking text in the editor shows Cut, Copy, Paste and the block's options; ⌥ right-click keeps the system menu for spelling.

### Changed

- The app can now save files you choose (Export as Markdown, #79); before, it could only open them.

### Fixed

- Updating from v0.5 (#84): a task that had both notes from before tasks had pages and a page body kept the notes out of sight after updating. The notes now become the first line of the body, and 0.5.1 testers get theirs back the next time the app opens.

### Removed

- The old hand-built block editor (#82). Pages, task pages and Quick note all use the TipTap editor, which brings selection, copy and paste, and undo across lines (closes #51).

## [0.5.1] — 2026-11-20

Pomodoro timers with a focus heat map, and the first part of the new TipTap editor (block handle, Turn into, the / menu). Markdown, the Make task badge and @ mentions follow in 0.5.5.

### Added

- Pomodoro (#89): a page under Views for focus timers. Start several at once with New timer (⌘T), each with its own name, focus length (25, 40, 50 or your own) and break (5, 10, 15 or none), and optionally a page it counts toward. Each card shows the time left, when it ends and today's sessions; pause (Space), skip a break, finish a session early or change lengths from ⋯. Timers keep going while the window is closed, and a notification says when focus or a break ends. Focus history shows a square for every finished session, a row per day, darker for longer sessions, and a GitHub-style year of days. The sidebar shows the time left on the timer ending soonest.

- The new page editor (#76): TipTap, bundled with the app and loaded from it, never from the network, with Schema's fonts and colours and a bridge for loading, saving, focus and Esc. Scratchpads and task pages now open in it (#77).

- Blocks in the new editor (#78): Return starts a new block and Shift+Return breaks the line inside it. Hovering a block shows one handle in the margin instead of a plus on every line: drag it to move the block, or click it for Turn into, Duplicate (⌘D) and Delete (⌫). Each line of a list is its own block. The / menu is back with the same kinds plus Code, and ⌘/ opens Turn into for the block with the caret. Menus use Schema's panel style in light and dark.

### Changed

- The data store moves to version 8, adding Pomodoro timers and sessions (#89). Nothing else changes.

- Page content is stored as one document per page and per task (#77), with a plain-text copy for search. Updating moves every existing line over: lists, ticks and each to-do's link to the task it was made into are kept, and a task's old notes become the first line of its page. Quick note writes into the same document. Until #80, the "Make task" badge is missing from the new editor; "Make tasks from open to-dos" in the page menu still works.

- The app can now make outgoing network connections. macOS needs this for the editor's web view to start at all, even though the editor itself only loads files from the app; GitHub (v0.6) uses it too.

- The app now declares that it uses no encryption, so TestFlight builds no longer stop at "Missing Compliance" waiting for the export question.

## [0.5.0] — 2026-11-17

Pages and capture: every page has a type, scratchpads with a block editor, the / menu and markdown shortcuts, tasks that open as pages, a Quick note panel from any app, page management, a floating collapsed sidebar, smoother motion and fast long pages.

### Fixed

- Contrast (#46): placeholder hints in scratchpads and task pages ("Type / for blocks", "Untitled", "Add notes, steps or links") and the + beside a line used the faint ink, 3.1–3.7:1. They now use the muted ink, 6.1:1 or better. Faint ink stays only on decorative marks: the breadcrumb "/" and done-checkbox rings.

### Changed

- Pages now have a type, To-do list or Scratchpad, and can hold blocks (text, heading, bullet, to-do, quote, divider); tasks can hold blocks too, for their own page later (#36). The data migrates to schema V6 automatically and every existing page stays a to-do list. Nothing in the window changes yet.
- New page (⌘N) opens a dialog with a name and a page type, To-do list or Scratchpad (#37). The sidebar shows a document icon for scratchpads, and tooltips name each page's type. A new scratchpad opens as an empty page until the editor lands (#38).
- Scratchpads are editable (#38): text, headings, bullets, to-dos, quotes and dividers. Return starts a new line (bullets and to-dos continue; Return on an empty one ends the list), Backspace at the start of a line turns it back into text or joins it with the line above, and the arrow keys move between lines. Edits save as you type. Hover a line for + to add one below; right-click to turn it into another kind or delete it. On a scratchpad, N, / and ⌘Z are left to typing.
- The / menu and markdown shortcuts (#39). Type / at the start of a line for a block menu that filters as you type (↑ ↓ to move, Return to choose, Esc to close). At the start of a text line, `#`, `-` or `*`, `[]`, `>` plus a space, or `---`, turn it into a heading, bullet, to-do, quote or divider. ⌘/ opens the same menu to change the current line's kind. Empty lines hint "Type / for blocks".
- Make task from a line (#40). Hover or edit an open to-do line in a scratchpad and click "Make task in …" (your default page from Settings), or right-click any line → Make task in → a page. The line stays in the note as a to-do with a "Task in Work ↗" chip that opens the task; checking either one checks both. Page options (⋯) can make tasks from every open to-do line at once.
- Tasks open as pages (#31). Double-click a task (or press Return on it) to open it in the main column: a breadcrumb back to its list (Esc), previous and next (⌘[ ⌘]), a large checkbox and an editable title, then a body of blocks like a scratchpad, with the / menu. To-do lines in a task are its steps. The right panel shows Properties (page, due date and time, reminder, routine and its days, the routine it follows, tags), checklist progress, where the task was made from, and its dates; property changes save right away. The ⋯ menu moves, duplicates or deletes the task. The v0.4 task editor in the right panel is gone, and a task's old notes become the first line of its page. In lists, a task's second line now comes from the first text line of its page.
- The collapsed right panel shows icons for its cards (reminders, week, routines; or properties, checklist, links on a task page).
- Quick note (#41). Press ⌃⌥N in any app while Schema is running: a small panel opens over what you're doing without bringing Schema forward. Return saves the note to the top of a scratchpad under today's date (newest first), ⇧Return adds a line, ⌘Return saves it as a task in your default page instead, Esc or a click elsewhere closes it. "Into:" picks the scratchpad; Settings → Quick note sets the default. If there's no scratchpad yet, the first note makes Ideas. Scratchpads also have a Quick note button.
- Fixed: long lines in a scratchpad could wrap at the wrong width and overlap the line below.
- Scratchpads never receive tasks: quick add, @page mentions, Move to page and the default page in Settings only offer to-do lists.
- Added the first unit tests (Swift Testing, `SchemaTests` target): block ordering, page and block models, and the V5 → V6 migration. Tests run against an in-memory store, never the real one.
- Pages can be renamed, deleted and reordered (#42). Rename and Delete page… are in each page's ••• menu and in the sidebar's right-click menu; Page titles are editable in place: click and type, Return or clicking away saves, Esc puts the old name back; Rename selects the title. The title keeps its letter spacing while you edit. Deleting asks once and removes the page's tasks or notes with it, cancelling their reminders; it can't be undone, and it clears ⌘Z history. Drag a page in the sidebar to move it: the row lifts and follows the pointer, the others slide aside, and the order is saved when you let go; ⌘1–9 follow the new order. A page can't be named Everything.
- Floating collapsed sidebar (#43). Collapsing the sidebar (⌘⌥←) now removes the column and the main column takes the full width. A slim floating bar sits at the top left, under the window controls, with Expand, Today, Upcoming, Everything, New page, Notifications and Settings; pages stay in the open sidebar. Content keeps a left margin so the bar never covers it, and a short window scrolls the bar without a scroll bar. The narrowest window is now 532pt.
- Motion polish (#44). One timing (320ms) for everything that moves: panels, rows, reordering, completing, scrolling to a task and showing completed tasks. Dialogs and the selection toolbar use the same timing to appear; hover and selection stay at 180ms. Collapsing the sidebar slides it out first, then the floating bar fades in; expanding fades the bar out before the sidebar slides back. Reduce Motion is now respected everywhere: movement is instant, slides become fades, and dialogs fade quickly.
- Performance with long pages (#45). Checked with a 1,000-task to-do list and a 500-line scratchpad. Opening either page went from 0.7 to 1.5 seconds down to about 0.1, and a keystroke on the long scratchpad from 136ms to about 17ms (Debug build). Task lists and scratchpads now build only the rows on screen. Pages and tasks are fetched again only when one is added or removed, not on every keystroke. The day stats, sidebar counts and linked-routine check each take one pass over the tasks, and the task list is kept between redraws that don't change it, such as moving the selection.

## [0.4.0] — 2026-11-15

The Mac redesign: a three-column window, the Schema design system (neutral greys, one yellow accent, Space Grotesk and Satoshi), sidebar navigation, redesigned to-do pages, a Today dashboard and an overview panel.

### Fixed

- Completed task titles and the sidebar's New page row now meet 4.5:1 text contrast in light and dark mode (#18).
- Setting a reminder could crash Schema, and then crash it again at every launch, when macOS refused to schedule the notification. Notification errors are now logged and the reminder time is still saved.

### Changed

- New color tokens from the Schema design system: neutral greys with a single yellow accent, in light and dark (#6).
- Lists no longer have their own colors; tabs, tags and list cards are neutral. The Change Color menu is gone.
- Bundled Space Grotesk (titles, numbers, times, counts, badges) and Satoshi (task titles, body text, buttons), with the design system's type styles (#7).
- Shared components in `Core/Design/Components`: pill buttons (primary, secondary, ghost, danger, ink), round icon buttons with tooltips, a quiet task checkbox, chips, count badges, key hints, section labels, cards and a flat progress bar (#8).
- Task rows, list tabs, the Add task bar, the Completed header and the New list and Rename dialogs now use these components. Press animations respect Reduce Motion (#4).
- Three-column window (#9): the title bar is hidden and the window controls sit at the top of a 240pt sidebar; the main column and a 300pt details panel each scroll on their own. Notifications and Settings (⌘,) moved from the toolbar into the sidebar header. Until panels can collapse, the window is at least 960pt wide.
- Side panels collapse to slim icon rails instead of hiding (#10): the sidebar to 72pt with ⌘⌥←, the details panel to 52pt with ⌘⌥→. Both are in the View menu, and Schema remembers each panel's state. The window can now narrow to 544pt.
- Side panels follow the window width (#11): 1200pt and wider shows both, 960–1199pt collapses the details panel, under 960pt collapses both. A panel you open or close by hand stays that way until the window crosses a breakpoint; opening one where both won't fit collapses the other.
- Sidebar navigation (#12): Views (Today, Upcoming, Everything) and Pages, with the active item as a dark pill and letter icons on the collapsed rail. Today lists tasks due today or overdue; Upcoming lists tasks due later (the dashboard versions come in #17). ⌘1–⌘9 now open pages, / opens Everything, and New page (⌘N) creates a to-do list. Collapsing the sidebar only changes its width: icons stay in place while labels clip and fade, section labels fade into dividers, and Notifications and Settings sit at the bottom in both states.
- The to-do page is redesigned (#13):
  - **Header:** a breadcrumb, sort pills (Manual, Due, A–Z) and a page-options menu, then a large title with the page type, its open count, and done-of-total with a progress bar.
  - **Quick add:** a full-width pill with a send button.
  - **Grouping:** open tasks are grouped into Today, Later this week, Later and Someday cards. Routine chains stay together.
  - **Drag to reorder:** drags stay inside a section.
  - **Completed:** completed tasks sit in a quiet collapsed card at the end.
  - The All Lists link and the List Preferences menu are gone; Filter now lives in page options.
- Selection toolbar (#14): selecting tasks shows a floating pill with the count, Reschedule (Today, Tomorrow, Next week, No date; keeps the time of day), Move to page, Delete, Complete (⇧↩) and Clear (Esc).
- Deleting tasks with the toolbar or ⌫ now asks once in a small dialog; Esc or a click outside cancels.
- Task details open in the right panel instead of a floating card (#15). The list stays visible beside them; the panel widens to 360pt while a task is open, even if it was collapsed, and returns to its saved state when closed. Delete in details now asks first, like the toolbar.
- The Routine switch no longer wraps letter by letter in the details panel; the weekdays sit on their own row.
- Removed the unused All Lists screen and the navigation container around the workspace.
- Tasks now record when they were completed (#16). The data migrates to schema V5 automatically; tasks completed before the update keep an empty completion date. This feeds Done today and the week chart (#17).
- Today is now a dashboard (#17): the date as title, tiles for Done today (with progress), Due today (with the next time) and This week, then today's tasks grouped by page. Today also counts routines that run today and tasks completed today.
- Upcoming lists future tasks grouped by day (Tomorrow, weekday, then date).
- Weeks start on Monday. Settings → Calendar → Week starts on can switch to Sunday; it applies to This week and the Later this week section.
- With no task open, the right panel shows an overview: the next four reminders, completions per day this week (today in yellow) and today's routines per page.

## [0.3.0] — 2026-11-12

### Fixed

- Task rows no longer squish or scroll out of view when switching list tabs (#1). The task list now uses a plain `ScrollView` instead of `List`, and each list opens scrolled to the top.
- Drag-to-reorder works while Schema is the active window (#3). Rows are dragged with a SwiftUI gesture, and an accent line shows where the task will land.
- Reordering in the Everything view or with a filter active drops tasks where you release them instead of jumping inside their own list (#3).
- Dragging while a non-Manual sort is active keeps the on-screen order when the list switches to Manual.

### Changed

- Dragging the first task of a routine chain moves the whole chain; drops never split a chain.
- Arrow-key selection scrolls only as far as needed instead of re-centering on every press.
- Internal: `ContentView` split into `ContentView` (window root), `WorkspaceView` (layout), and `WorkspaceView+Actions`; selection, focus, and panel state moved into `WorkspaceState`. The AppKit mouse shim `ListRowMouseHandler` was removed.

## [0.2.0] — 2026-06-21

### Added

- Detailed task view sheet — open with Return or double-click on a selected task
- Edit task title, description, reminder, routine schedule, and sequence order in the detail sheet
- Routine tasks with daily sequencing and ordered completion chains
- Drag-to-reorder tasks when sort is Manual (`manualSortIndex` persisted per list)
- Inline `@` mentions in quick add and task title — assign list, time, date (`@tomorrow`, `@3pm`, `@ListName`)
- List suggestion picker with keyboard ↑/↓ when multiple lists match
- Native settings layout with Notifications, Default List, and Routine sections
- Setting to complete follower routine tasks without finishing the parent first
- All Lists context menu — rename, change color, delete
- SwiftData versioned schema (V1–V4) with migration plan for upgrades from v0.1
- Recoverable launch screen when the local store fails (Retry / Reset Data)

### Changed

- Return on a selected task opens the detail sheet (replaces inline title editing)
- Settings uses divider-based sections instead of card-style group boxes

### Fixed

- Task row checkbox clicks no longer blocked by list click handler
- Double-click to open task detail works reliably after checkbox interaction

## [0.1.0] — 2026-06-14

### Added

- Multiple task lists with horizontal tab navigation
- Rapid keyboard task entry (`n` to focus, `Enter` to save)
- List switching via `Cmd+1` through `Cmd+9`
- SwiftData persistence for lists and tasks
- Optional task reminders via macOS notifications
- Everything view aggregating tasks across all lists
- All Lists grid overview
- Sort and filter preferences (persisted across launches)
- Default writable list setting for Everything view
- Undo for task actions (`Cmd+Z`)
- Internal TestFlight distribution (macOS)

### Known limitations

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for the full v0.1 limitation list.

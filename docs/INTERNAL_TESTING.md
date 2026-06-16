# Internal Testing Guide

Schema v0.1 is distributed via **TestFlight for Mac** for internal testing.

## App names

| Context | Name |
|---------|------|
| App Store Connect / TestFlight listing | **Schema: Fast, Simple Todos** |
| Dock, menubar, in-app | **Schema** |
| Bundle ID | `com.sarkarshubhdeep.schema` |

## Prerequisites (App Store Connect admin)

- [x] App ID registered: `com.sarkarshubhdeep.schema` (iOS + macOS enabled; v0.1 uploads are macOS only)
- [x] App created in App Store Connect with listing name **Schema: Fast, Simple Todos**
- [ ] Internal testers added under **Users and Access** or **TestFlight → Internal Testing**

## Installing as a tester

1. Install [TestFlight for Mac](https://apps.apple.com/app/testflight/id899247664) from the Mac App Store.
2. Accept the email invite from App Store Connect (or open the TestFlight invite link).
3. Open TestFlight, select **Schema: Fast, Simple Todos**, and click **Install**.
4. Launch **Schema** from TestFlight or the Applications folder.

## System requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `n` | Open quick-add task field |
| `Enter` | Save task (when add field is focused) |
| `Esc` | Close add task field |
| `Cmd+Z` | Undo last task action |
| `Cmd+N` | New list |
| `Cmd+1` … `Cmd+9` | Switch to list 1–9 |
| `Ctrl+Tab` | Next list |
| `Ctrl+Shift+Tab` | Previous list |
| `/` | Jump to Everything list |

## What to test

### Core flows

- [ ] First launch seeds default lists (Everything, Daily Todos, Github Work, Groceries)
- [ ] Create, complete, and delete tasks
- [ ] Undo after completing or deleting a task
- [ ] Switch lists via tabs and `Cmd+1`–`Cmd+9`
- [ ] Quick entry: press `n`, type, press Enter
- [ ] Everything view shows tasks from all lists
- [ ] All Lists grid opens and navigates to a list

### Settings & persistence

- [ ] Change sort/filter via list preferences menu — quit and relaunch — preferences should persist
- [ ] Change default writable list in Settings — quit and relaunch — setting should persist
- [ ] Request notification permission in Settings
- [ ] Set a task reminder and confirm it appears in the notifications popover

### Edge cases

- [ ] Create a new list and add tasks to it
- [ ] Rename a list (not Everything)
- [ ] Delete a list (not Everything)
- [ ] Version shown in Settings matches the TestFlight build

## Reporting bugs

Include in every report:

1. **Version** from Settings (e.g. `0.1 (1)`)
2. **macOS version** (Apple menu → About This Mac)
3. **Steps to reproduce**
4. **Expected vs actual behavior**
5. **Screenshot or screen recording** if applicable

File issues on GitHub or contact the maintainer directly.

## Known issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

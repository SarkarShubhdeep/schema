//
//  BlockTaskLinks.swift
//  Schema
//
//  Make task from a line (#40, #80). A to-do in a page can become a task in
//  a to-do list; the line stays in the page linked to the task, and
//  ticking either one ticks both. The editor asks for these through the
//  bridge (PageBodyEditor).
//

import Foundation

/// What the editor needs from the rest of the app to link lines to tasks.
/// The workspace supplies it, so the editor doesn't own task logic.
struct BlockTaskActions {
    /// To-do lists a task can go to, in sidebar order.
    var taskPages: [SchemaList]
    /// Where "Make task" puts a task without asking (Settings' default page).
    var defaultPage: SchemaList?
    var task: (UUID) -> SchemaTask?
    var makeTask: (_ title: String, _ page: SchemaList) -> SchemaTask?
    var toggleTask: (SchemaTask) -> Void
    var openTask: (SchemaTask) -> Void
    /// Move task to … on a linked to-do (#80).
    var moveTask: (SchemaTask, SchemaList) -> Void = { _, _ in }
}

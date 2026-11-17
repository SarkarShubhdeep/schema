//
//  DemoBenchmark.swift
//  Schema
//
//  Debug-only timing harness for the performance pass (#45). With
//  `-SchemaDemoData -SchemaDemoLarge -SchemaDemoBenchmark`, it switches
//  between the large pages and edits them, printing how long each step
//  takes until the next run loop turn (after SwiftUI has updated and laid
//  out the window).
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DemoBenchmark {
    private struct Step {
        let label: String
        let action: () -> Void
    }

    static func run(lists: [SchemaList], listViewModel: ListViewModel, workspace: WorkspaceState, context: ModelContext) {
        guard let backlog = lists.first(where: { $0.title == "Backlog" }),
              let journal = lists.first(where: { $0.title == "Journal" }) else { return }
        let tasks = (try? context.fetch(FetchDescriptor<SchemaTask>()))?.filter { $0.list?.id == backlog.id } ?? []
        let blocks = (try? context.fetch(FetchDescriptor<SchemaBlock>()))?.filter { $0.page?.id == journal.id }
            .sorted { $0.sortIndex < $1.sortIndex } ?? []
        let typed = blocks.count > 250 ? blocks[250] : blocks.last

        var steps: [Step] = []
        if CommandLine.arguments.contains("-SchemaDemoBenchmarkSwitch") {
            // Switching only, between a short view and a short page.
            let daily = lists.first { $0.title == "Daily Todos" }
            for n in 1...40 {
                steps.append(Step(label: "open Today #\(n)") { listViewModel.selectSmartView(.today, from: lists) })
                steps.append(Step(label: "open Daily Todos #\(n)") { listViewModel.selectList(daily) })
            }
            perform(steps[...], results: [:], order: [])
            return
        }
        if CommandLine.arguments.contains("-SchemaDemoBenchmarkTyping") {
            // Typing only, for profiling one keystroke at a time.
            steps.append(Step(label: "open Journal for typing") { listViewModel.selectList(journal) })
            for n in 1...150 {
                steps.append(Step(label: "type in Journal #\(n)") {
                    if let typed { typed.text += "x" }
                })
            }
            perform(steps[...], results: [:], order: [])
            return
        }
        for n in 1...10 {
            steps.append(Step(label: "nothing (timer floor) #\(n)") {})
        }
        for round in 1...3 {
            steps.append(Step(label: "open Backlog (1,000 tasks) #\(round)") { listViewModel.selectList(backlog) })
            steps.append(Step(label: "open Journal (500 blocks) #\(round)") { listViewModel.selectList(journal) })
            steps.append(Step(label: "open Everything #\(round)") { listViewModel.selectEverythingList(from: lists) })
            steps.append(Step(label: "open Today #\(round)") { listViewModel.selectSmartView(.today, from: lists) })
        }
        steps.append(Step(label: "open Journal for typing") { listViewModel.selectList(journal) })
        for n in 1...20 {
            steps.append(Step(label: "type in Journal #\(n)") {
                if let typed { typed.text += "x" }
            })
        }
        // Selecting a task scrolls the list to it: step down the long list
        // about a screenful at a time.
        steps.append(Step(label: "open Backlog for scrolling") { listViewModel.selectList(backlog) })
        let open = tasks.filter { !$0.isCompleted }.sorted { $0.manualSortIndex < $1.manualSortIndex }
        for n in 1...30 where open.count > n * 12 {
            steps.append(Step(label: "scroll Backlog #\(n)") { workspace.selectSingle(open[n * 12].id) })
        }
        steps.append(Step(label: "open Backlog for completing") { listViewModel.selectList(backlog) })
        for n in 1...10 where tasks.count > n * 3 {
            steps.append(Step(label: "complete in Backlog #\(n)") {
                let task = tasks[n * 3 + 1]
                task.setCompleted(!task.isCompleted)
            })
        }
        for n in 1...10 where tasks.count > n * 3 {
            steps.append(Step(label: "rename in Backlog #\(n)") {
                tasks[n * 3 + 2].title += "!"
            })
        }
        perform(steps[...], results: [:], order: [])
    }

    private static func perform(_ steps: ArraySlice<Step>, results: [String: [Double]], order: [String]) {
        guard let step = steps.first else {
            report(results, order: order)
            return
        }
        let start = DispatchTime.now().uptimeNanoseconds
        step.action()
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                let key = step.label.replacingOccurrences(of: #" #\d+$"#, with: "", options: .regularExpression)
                var results = results
                var order = order
                if results[key] == nil { order.append(key) }
                results[key, default: []].append(ms)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    perform(steps.dropFirst(), results: results, order: order)
                }
            }
        }
    }

    private static func report(_ results: [String: [Double]], order: [String]) {
        print("BENCHMARK begin")
        for key in order {
            let values = results[key] ?? []
            let median = values.sorted()[values.count / 2]
            let worst = values.max() ?? 0
            print(String(format: "BENCHMARK %-36@ median %7.1f ms   worst %7.1f ms   (n=%d)", key as NSString, median, worst, values.count))
        }
        print("BENCHMARK end")
        fflush(stdout)
    }
}
#endif

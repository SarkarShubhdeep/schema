//
//  RoutineResetService.swift
//  Schema
//

import Foundation
import SwiftData

@MainActor
final class RoutineResetService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func resetRoutineTasksIfNeeded(tasks: [SchemaTask]) {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        let startOfToday = calendar.startOfDay(for: Date())

        for task in tasks where task.isRoutine && task.isCompleted {
            let shouldResetToday = task.effectiveRoutineDays.contains(today)

            guard shouldResetToday else { continue }

            let alreadyResetToday: Bool
            if let lastReset = task.lastRoutineReset {
                alreadyResetToday = calendar.isDate(lastReset, inSameDayAs: Date())
            } else {
                alreadyResetToday = false
            }

            guard !alreadyResetToday else { continue }

            let wasCompletedBeforeToday: Bool
            if let lastReset = task.lastRoutineReset {
                wasCompletedBeforeToday = lastReset < startOfToday
            } else {
                wasCompletedBeforeToday = task.createdAt < startOfToday
            }

            if wasCompletedBeforeToday {
                task.isCompleted = false
                task.lastRoutineReset = Date()
            }
        }

        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save routine reset: \(error)")
        }
    }
}

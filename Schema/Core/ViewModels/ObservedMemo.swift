//
//  ObservedMemo.swift
//  Schema
//
//  Keeps a value worked out from observable models until something it read
//  changes (#45).
//
//  The task list's sections and the day stats are rebuilt from every task
//  on each redraw, including redraws that change nothing they depend on,
//  like moving the selection. The memo records what the computation reads
//  (with Observation) and drops the value as soon as any of it changes;
//  views that read the memo redraw then and get a fresh value. Inputs that
//  aren't observable (the day, say) go in `key`.
//

import Foundation
import Observation

@MainActor
@Observable
final class ObservedMemo<Value> {
    /// Bumped when the value goes stale, so views that read it redraw.
    private var generation = 0

    @ObservationIgnored private var cached: Value?
    @ObservationIgnored private var cachedKey: AnyHashable?

    func value(key: AnyHashable, compute: () -> Value) -> Value {
        _ = generation
        if let cached, cachedKey == key { return cached }
        let value = withObservationTracking(compute) { [weak self] in
            // Called just before a property it read changes.
            MainActor.assumeIsolated { self?.invalidate() }
        }
        cached = value
        cachedKey = key
        return value
    }

    private func invalidate() {
        guard cached != nil else { return }
        cached = nil
        cachedKey = nil
        generation &+= 1
    }
}

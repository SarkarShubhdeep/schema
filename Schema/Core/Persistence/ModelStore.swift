//
//  ModelStore.swift
//  Schema
//
//  All models of one type, fetched again only when a save adds or removes
//  one (#45).
//
//  `@Query` re-fetches whenever anything in the context changes. With a
//  1,000-task store that meant a full fetch of every task on each
//  keystroke in a scratchpad, about 60% of the time spent typing. Edits to
//  a model's properties don't need a fetch: models are observable, so views
//  that read a property update on their own. Only inserts and deletes
//  change which models exist, and the app saves right after each one.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ModelStore<Model: PersistentModel> {
    private(set) var items: [Model] = []

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(context: ModelContext) {
        self.context = context
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let changed = Self.changesMembership(notification)
            MainActor.assumeIsolated {
                if changed { self?.reload() }
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        items = (try? context.fetch(FetchDescriptor<Model>())) ?? []
    }

    /// Whether a save inserted or deleted a model of this type.
    nonisolated private static func changesMembership(_ notification: Notification) -> Bool {
        let entity = String(describing: Model.self)
        let keys = [
            ModelContext.NotificationKey.insertedIdentifiers.rawValue,
            ModelContext.NotificationKey.deletedIdentifiers.rawValue,
        ]
        return keys.contains { key in
            let ids = notification.userInfo?[key] as? [PersistentIdentifier] ?? []
            return ids.contains { $0.entityName == entity }
        }
    }
}

//
//  SchemaNotificationItem.swift
//  Schema
//

import Foundation

struct SchemaNotificationItem: Identifiable, Equatable {
    let id: String
    let taskID: UUID?
    let listID: UUID?
    let title: String
    let subtitle: String?
    let fireDate: Date
}

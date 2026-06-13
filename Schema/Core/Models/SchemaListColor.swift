//
//  SchemaListColor.swift
//  Schema
//

import Foundation

enum SchemaListColorName: String, CaseIterable, Identifiable {
    case neutral
    case grey
    case blue
    case purple
    case green
    case orange

    var id: String { rawValue }

    static func fallback(for title: String) -> SchemaListColorName {
        switch title {
        case SchemaList.everythingTitle:
            return .neutral
        case "Daily Todos":
            return .grey
        case "Github Work":
            return .blue
        case "Groceries":
            return .purple
        default:
            let hash = abs(title.hashValue)
            let options: [SchemaListColorName] = [.grey, .blue, .purple, .green, .orange]
            return options[hash % options.count]
        }
    }
}

//
//  PageDocumentHolder.swift
//  Schema
//
//  Pages and tasks both hold a TipTap document (schema V7, #77). Saving it
//  also stores what is derived from it, so lists, search and the task
//  panel read plain fields instead of parsing JSON.
//

import Foundation

protocol PageDocumentHolder: AnyObject {
    var documentData: Data? { get set }
    var documentText: String { get set }
    var linkedTaskIDsRaw: String { get set }
    var checklistCount: Int { get set }
    var checklistDoneCount: Int { get set }
    var documentEditedAt: Date? { get set }
}

extension PageDocumentHolder {
    /// The document as TipTap JSON text; an empty paragraph when there is none.
    var documentJSON: String {
        documentData.flatMap { String(data: $0, encoding: .utf8) } ?? PageDocument.emptyJSON
    }

    var hasDocument: Bool { documentData != nil }

    /// Tasks made from to-dos in this document.
    var linkedTaskIDs: [UUID] {
        linkedTaskIDsRaw.split(separator: " ").compactMap { UUID(uuidString: String($0)) }
    }

    /// Stores `json` and what is derived from it. Returns false when it is
    /// the document already stored.
    @discardableResult
    func setDocument(_ json: String, editedAt date: Date = .now) -> Bool {
        let data = Data(json.utf8)
        guard data != documentData else { return false }
        let summary = PageDocument.summary(of: json)
        documentData = data
        documentText = summary.text
        linkedTaskIDsRaw = summary.linkedTaskIDs.map(\.uuidString).joined(separator: " ")
        checklistCount = summary.checklistCount
        checklistDoneCount = summary.checklistDoneCount
        documentEditedAt = date
        return true
    }
}

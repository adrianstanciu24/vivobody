//
//  CatalogMovementFamily.swift
//  vivobody
//
//  Immutable, generated family actions for coverage drill-outs. Action kind
//  preserves the distinction between moving, resisting, and yielding. These
//  catalog facts never become SwiftData fields or overwrite logged snapshots.
//

import Foundation

nonisolated struct CatalogMovementAction: Decodable, Hashable, Identifiable {
    enum Kind: String, Decodable, Hashable {
        case produced, resisted, yielding
    }

    let actionID: String
    let name: String
    let plane: MovementPlane
    let kind: Kind

    var id: String {
        "\(kind.rawValue):\(actionID)"
    }

    var displayName: String {
        switch kind {
        case .produced: name
        case .resisted: "Resisting \(name.lowercased())"
        case .yielding: "Yielding through \(name.lowercased())"
        }
    }
}

nonisolated struct CatalogMovementFamily: Identifiable {
    let id: String
    let name: String
    let planes: Set<MovementPlane>
    let actions: [CatalogMovementAction]

    static let bundled: [CatalogMovementFamily] = make(from: CatalogData.records)

    static func make(from records: [CatalogRecord]) -> [CatalogMovementFamily] {
        var seen: Set<String> = []
        return records.compactMap { record in
            guard record.modality.supportsHardSetAnalytics,
                  seen.insert(record.familyID).inserted else { return nil }
            return CatalogMovementFamily(
                id: record.familyID, name: record.familyName,
                planes: Set(record.planes), actions: record.movementActions
            )
        }.sorted { $0.name < $1.name }
    }

    enum ValidationError: Error {
        case invalidActions(String)
        case inconsistentFamily(String)
    }

    static func validate(_ records: [CatalogRecord]) throws {
        var families: [String: CatalogRecord] = [:]
        for record in records {
            guard !record.familyName.trimmingCharacters(in: .whitespaces).isEmpty,
                  !record.movementActions.isEmpty,
                  Set(record.movementActions.map(\.id)).count == record.movementActions.count,
                  record.movementActions.allSatisfy({ !$0.actionID.isEmpty && !$0.name.isEmpty })
            else { throw ValidationError.invalidActions(record.catalogID) }
            if let first = families[record.familyID] {
                guard first.familyName == record.familyName,
                      first.movementActions == record.movementActions
                else { throw ValidationError.inconsistentFamily(record.familyID) }
            }
            families[record.familyID] = record
        }
    }
}

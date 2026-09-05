//
//  CatalogMovementMetadataTests.swift
//  vivobodyTests
//
// Runtime family action decoding stays strict and consistent across variants.

import Foundation
import Testing
@testable import vivobody

@MainActor
struct CatalogMovementMetadataTests {
    private func recordJSON() throws -> [[String: Any]] {
        let url = try #require(Bundle.main.url(forResource: "catalog", withExtension: "json"))
        let values = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        return Array(values.prefix(1))
    }

    @Test func missingActionsAndUnknownKindsFailDecoding() throws {
        var values = try recordJSON()
        values[0].removeValue(forKey: "movementActions")
        let missing = try JSONSerialization.data(withJSONObject: values)
        #expect(throws: (any Error).self) { try CatalogData.decode(missing) }
        values = try recordJSON()
        var actions = try #require(values[0]["movementActions"] as? [[String: Any]])
        actions[0]["kind"] = "stabilizing"
        values[0]["movementActions"] = actions
        let invalid = try JSONSerialization.data(withJSONObject: values)
        #expect(throws: (any Error).self) { try CatalogData.decode(invalid) }
    }

    @Test func emptyAndDuplicateActionListsAreRejected() throws {
        var values = try recordJSON()
        let actions = try #require(values[0]["movementActions"] as? [[String: Any]])
        for invalid in [[], actions + actions] {
            values[0]["movementActions"] = invalid
            let data = try JSONSerialization.data(withJSONObject: values)
            #expect(throws: (any Error).self) { try CatalogData.decode(data) }
        }
    }

    @Test func coverageRosterIsFamilyDeduplicatedAndExcludesPowerOnlyFamilies() {
        let families = CatalogMovementFamily.bundled
        #expect(Set(families.map(\.id)).count == families.count)
        #expect(!families.contains { $0.id == "power-clean" })
        #expect(families.filter { $0.id == "horizontal-press" }.count == 1)
        #expect(families.first { $0.id == "glute-ham-raise" }?.actions.contains { $0.kind == .yielding } == true)
    }
}

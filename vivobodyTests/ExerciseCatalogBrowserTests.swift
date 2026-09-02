//
//  ExerciseCatalogBrowserTests.swift
//  vivobodyTests
//
//  Guards the shared Library/picker browse projection: grouped versus ranked
//  modes, scope ordering, history lookup, eligible filter options, row metadata,
//  and purpose-specific picker eligibility.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseCatalogBrowserTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(
        _ name: String,
        id: UUID = UUID(),
        catalogID: String? = nil,
        group: MuscleGroup = .back,
        equipment: Equipment = .barbell,
        mechanic: Mechanic = .compound,
        trainingRole: TrainingRole? = nil,
        pattern: MovementPattern? = .pull,
        direction: PushPullDirection? = .horizontal,
        modality: ExerciseModality = .dynamicStrength,
        isUserCreated: Bool = true
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            id: id,
            catalogID: catalogID,
            name: name,
            group: group,
            defaultWeight: 100,
            modality: modality,
            equipment: equipment,
            mechanic: mechanic,
            trainingRole: trainingRole,
            pattern: pattern,
            direction: direction,
            isUserCreated: isUserCreated,
            createdAt: now
        )
    }

    private func snapshot(
        items: [ExerciseCatalogItem],
        query: String = "",
        filter: ExerciseCatalogFilter = .all,
        history: [String: LastExerciseInstance] = [:],
        includes: (ExerciseCatalogItem) -> Bool = { _ in true }
    ) -> ExerciseCatalogBrowserSnapshot {
        ExerciseCatalogBrowserSnapshot(
            items: items,
            query: query,
            filter: filter,
            lastInstanceLookup: history,
            unit: .kg,
            includes: includes
        )
    }

    @Test func blankQueryGroupsScopedItemsWithoutRunningSearch() {
        let chest = item("Chest Press", group: .chest, trainingRole: .push, pattern: .push)
        let back = item("Cable Row", group: .back, equipment: .cable, trainingRole: .pull)
        let browser = snapshot(items: [back, chest], query: "   ")

        #expect(!browser.isSearching)
        #expect(browser.searchResults.isEmpty)
        #expect(Set(browser.sections.map(\.group)) == [.chest, .back])
        #expect(browser.sections.flatMap(\.items).count == 2)
        #expect(browser.unit == .kg)
    }

    @Test func scopeIsAppliedBeforeRankedSearch() {
        let barbell = item("Barbell Row", equipment: .barbell)
        let band = item("Band Row", equipment: .band)
        let browser = snapshot(
            items: [barbell, band],
            query: "row",
            filter: .equipment(.band)
        )

        #expect(browser.isSearching)
        #expect(browser.sections.isEmpty)
        #expect(browser.searchResults.map(\.name) == ["Band Row"])
    }

    @Test func historyLookupAlsoSuppliesSearchTieBreaker() throws {
        let alphabetical = item("Bar Row")
        let tracked = item("Box Row")
        let last = LastExerciseInstance(
            topWeight: 100,
            topReps: 8,
            sessionDate: now,
            isAllTimeBest: false
        )
        let browser = snapshot(
            items: [alphabetical, tracked],
            query: "row",
            history: [tracked.historyKey: last]
        )

        #expect(browser.searchResults.first?.id == tracked.id)
        #expect(try #require(browser.lastInstance(for: tracked)) == last)
        #expect(browser.lastInstance(for: alphabetical) == nil)
    }

    @Test func filterOptionsReflectOnlyEligibleCatalogItems() {
        let barbell = item("Barbell Press", group: .chest, trainingRole: .push, pattern: .push)
        let excludedCore = item("Cable Crunch", group: .core, equipment: .cable)
        let browser = snapshot(
            items: [barbell, excludedCore],
            includes: { $0.id == barbell.id }
        )
        let options = browser.filterOptions(includingCore: true)

        #expect(browser.availableEquipment == [.barbell])
        #expect(options.contains(.equipment(.barbell)))
        #expect(!options.contains(.equipment(.cable)))
        #expect(!options.contains(.core))
    }

    @Test func sharedMetadataKeepsMovementAndIsolationVocabulary() {
        let press = item(
            "Bench Press",
            group: .chest,
            trainingRole: .push,
            pattern: .push,
            direction: .horizontal
        )
        let curl = item(
            "Band Curl",
            equipment: .band,
            mechanic: .isolation,
            trainingRole: .pull,
            pattern: nil,
            direction: nil
        )
        let browser = snapshot(items: [press, curl])

        #expect(browser.metadataLine(for: press) == "Barbell · Horizontal Push")
        #expect(browser.metadataLine(for: curl) == "Band · Pull · Isolation")
    }

    @Test func pickerPurposeOwnsExclusionsAndRoutineEligibility() {
        let anchorID = UUID()
        let anchor = item("Anchor", id: anchorID)
        let custom = item("Custom")
        let comparison = ExercisePickerPurpose.compare(
            anchorID: anchorID,
            anchorName: "Anchor"
        )

        #expect(!comparison.includes(anchor))
        #expect(comparison.includes(custom))

        let routine = ExercisePickerPurpose.routineSwap(
            excludedIDs: [],
            equipment: [.barbell],
            compatibleCatalogIDs: ["allowed", "power"]
        )
        let allowed = item("Allowed", catalogID: "allowed", isUserCreated: false)
        let wrongID = item("Wrong ID", catalogID: "wrong", isUserCreated: false)
        let wrongEquipment = item(
            "Dumbbell",
            catalogID: "allowed",
            equipment: .dumbbell,
            isUserCreated: false
        )
        let power = item(
            "Power",
            catalogID: "power",
            modality: .power,
            isUserCreated: false
        )

        #expect(routine.includes(allowed))
        #expect(!routine.includes(wrongID))
        #expect(!routine.includes(wrongEquipment))
        #expect(!routine.includes(power))
        #expect(!routine.includes(custom))
        #expect(!routine.allowsCatalogEditing)
    }
}

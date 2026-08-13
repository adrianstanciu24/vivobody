//
//  CatalogDuplicateTests.swift
//  vivobodyTests
//
//  Proves the duplicate-as-custom flow: the prefilled draft keeps the
//  source exercise's semantics, anatomy, and defaults while clearing
//  the search terms the source owns; the suggested "(Custom)" name
//  always clears the global name/alias namespace; and a saved copy
//  gets a fresh history identity that never collides with the bundled
//  original.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct CatalogDuplicateTests {

    /// A bundled bodyweight-plus-load compound. Between this and the
    /// plank fixture, every field the draft carries holds a value that
    /// differs from `CatalogDraft.empty`, so a missing copy cannot
    /// hide behind a matching default.
    private func makePullUpItem() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "weighted-pull-up",
            familyID: "vertical-pull",
            name: "Weighted Pull-Up",
            group: .back,
            defaultWeight: 45,
            defaultReps: 6,
            defaultWeightKg: 20,
            trackingMode: .reps,
            modality: .dynamicStrength,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 0.95,
            equipment: .bodyweight,
            mechanic: .compound,
            pattern: .pull,
            direction: .vertical,
            planes: [.sagittal, .frontal],
            laterality: .bilateral,
            aliases: ["WPU"],
            movementDefinition: "Hang from a bar with added load and pull the chin above it.",
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .lats, role: .primary),
                .init(muscle: .bicepsBrachii, role: .secondary),
                .init(muscle: .fingerFlexors, role: .stabilizer),
            ])
        )
    }

    /// A bundled duration lift: covers the tracking / modality /
    /// mechanic / plane / laterality combinations the pull-up fixture
    /// doesn't (timed hold, isolation, nil pattern and direction).
    private func makePlankItem() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "side-plank",
            familyID: "anti-lateral-flexion",
            name: "Side Plank",
            group: .core,
            defaultWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .nonComparable,
            bodyweightFraction: 0,
            defaultDuration: 30,
            equipment: .bodyweight,
            mechanic: .isolation,
            pattern: nil,
            direction: nil,
            planes: [.frontal],
            laterality: .unilateral,
            aliases: [],
            movementDefinition: "Hold a straight line balanced on one forearm and the side of one foot.",
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .obliques, role: .primary),
                .init(muscle: .gluteMed, role: .stabilizer),
            ])
        )
    }

    @Test func duplicateDraftPreservesSemanticsAndAnatomy() {
        let source = makePullUpItem()
        let draft = CatalogDraft(duplicating: source, defaultWeight: source.defaultWeight)

        #expect(draft.group == source.group)
        #expect(draft.trackingMode == source.trackingMode)
        #expect(draft.modality == source.modality)
        #expect(draft.loadMode == source.loadMode)
        #expect(draft.bodyweightFraction == source.bodyweightFraction)
        #expect(draft.equipment == source.equipment)
        #expect(draft.mechanic == source.mechanic)
        #expect(draft.pattern == source.pattern)
        #expect(draft.direction == source.direction)
        #expect(draft.planes == source.planes)
        #expect(draft.laterality == source.laterality)
        #expect(draft.movementDefinition == source.movementDefinition)
        #expect(draft.muscleInvolvementSnapshot == source.muscleInvolvementSnapshot)
    }

    @Test func duplicateDraftPreservesDurationAndIsolationSemantics() {
        let source = makePlankItem()
        let draft = CatalogDraft(duplicating: source, defaultWeight: source.defaultWeight)

        #expect(draft.trackingMode == .duration)
        #expect(draft.modality == .isometricStrength)
        #expect(draft.mechanic == .isolation)
        #expect(draft.pattern == nil)
        #expect(draft.direction == nil)
        #expect(draft.planes == [.frontal])
        #expect(draft.laterality == .unilateral)
        // 30s, not the 45s fallback `CatalogDraft.empty` would imply.
        #expect(draft.defaultDuration == 30)
        #expect(draft.muscleInvolvementSnapshot == source.muscleInvolvementSnapshot)
    }

    @Test func duplicateDraftClearsSourceSearchTerms() {
        let source = makePullUpItem()
        let draft = CatalogDraft(duplicating: source, defaultWeight: source.defaultWeight)

        // The source owns its name and aliases in the shared search
        // namespace, so the copy must start with neither.
        #expect(draft.name == "Weighted Pull-Up (Custom)")
        #expect(draft.parsedAliases.isEmpty)
    }

    @Test func duplicateDraftUsesUnitAwareWeightSeed() {
        let source = makePullUpItem()

        // kg users keep the source's clean kg-grid default (20 kg)
        // instead of the off-grid conversion of the 45 lb default.
        let kgDraft = CatalogDraft(
            duplicating: source,
            defaultWeight: source.defaultWeight(forUnit: .kg)
        )
        #expect(kgDraft.defaultWeight != source.defaultWeight)
        #expect(abs(WeightFormatter.toDisplay(kgDraft.defaultWeight, unit: .kg) - 20) < 0.0001)

        let lbDraft = CatalogDraft(
            duplicating: source,
            defaultWeight: source.defaultWeight(forUnit: .lb)
        )
        #expect(lbDraft.defaultWeight == 45)
    }

    @Test func duplicateNameIncrementsUntilUnique() {
        #expect(CatalogDraft.duplicateName(base: "Bench Press", taken: []) == "Bench Press (Custom)")

        // Collision matching is case- and whitespace-insensitive, the
        // same normalization the editor's uniqueness validation uses.
        #expect(CatalogDraft.duplicateName(
            base: "Bench Press",
            taken: ["BP", "bench  press (custom)"]
        ) == "Bench Press (Custom 2)")

        #expect(CatalogDraft.duplicateName(
            base: "Bench Press",
            taken: ["Bench Press (Custom)", "Bench Press (Custom 2)"]
        ) == "Bench Press (Custom 3)")
    }

    @Test func savedCopyGetsFreshHistoryIdentity() {
        let source = makePullUpItem()

        // Mirrors the editor's create-path insert for a duplicate.
        let copy = ExerciseCatalogItem(
            name: "Weighted Pull-Up (Custom)",
            group: source.group,
            defaultWeight: source.defaultWeight,
            defaultReps: source.defaultReps,
            trackingMode: source.trackingMode,
            modality: source.modality,
            loadMode: source.loadMode,
            bodyweightFraction: source.bodyweightFraction,
            defaultDuration: source.defaultDuration,
            equipment: source.equipment,
            mechanic: source.mechanic,
            pattern: source.pattern,
            direction: source.direction,
            planes: source.planes,
            laterality: source.laterality,
            aliases: [],
            movementDefinition: source.movementDefinition,
            muscleInvolvement: source.muscleInvolvement,
            isUserCreated: true
        )

        #expect(copy.catalogID == nil)
        #expect(copy.isUserCreated)
        // The create flow's 8/12 rep heuristic must not reset the
        // source's rep default.
        #expect(copy.defaultReps == 6)
        #expect(source.historyKey == "bundled:weighted-pull-up")
        #expect(copy.historyKey != source.historyKey)
        #expect(copy.historyKey.contains(copy.id.uuidString))
    }
}

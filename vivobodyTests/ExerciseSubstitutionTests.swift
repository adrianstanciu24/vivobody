//
//  ExerciseSubstitutionTests.swift
//  vivobodyTests
//
//  Proves deterministic exercise-substitution eligibility, structural
//  ordering, familiarity tie-breaks, typed tradeoffs, and honest explanation
//  copy without persistence or presentation dependencies.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseSubstitutionTests {
    // MARK: - Fixtures

    private func item(
        catalogID: String?,
        familyID: String? = "incline-press",
        name: String,
        primaryMuscles: [Muscle] = [.pectoralisMajorClavicular],
        secondaryMuscles: [Muscle] = [.deltoidAnterior, .triceps],
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        equipment: Equipment = .barbell,
        mechanic: Mechanic = .compound,
        pattern: MovementPattern? = .push,
        direction: PushPullDirection? = .diagonal,
        planes: [MovementPlane] = [.sagittal],
        laterality: Laterality = .bilateral,
        isFavorite: Bool = false
    ) -> ExerciseCatalogItem {
        let contributions = primaryMuscles.map {
            Muscle.Involvement.Contribution(muscle: $0, role: .primary)
        } + secondaryMuscles.map {
            Muscle.Involvement.Contribution(muscle: $0, role: .secondary)
        }
        let result = ExerciseCatalogItem(
            catalogID: catalogID,
            familyID: familyID,
            name: name,
            group: .chest,
            defaultWeight: 100,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            equipment: equipment,
            mechanic: mechanic,
            trainingRole: .push,
            pattern: pattern,
            direction: direction,
            planes: planes,
            laterality: laterality,
            muscleInvolvement: Muscle.Involvement(contributions: contributions)
        )
        result.isFavorite = isFavorite
        return result
    }

    private func catalogIDs(
        _ recommendations: [ExerciseSubstitution.Recommendation]
    ) -> [String] {
        recommendations.compactMap(\.candidate.catalogID)
    }

    // MARK: - Eligibility

    @Test func excludesSourceAndDifferentWorkoutSemantics() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let valid = item(catalogID: "valid", name: "Incline Dumbbell Press")
        let power = item(
            catalogID: "power",
            name: "Incline Power Press",
            modality: .power
        )
        let timed = item(
            catalogID: "timed",
            name: "Incline Press Hold",
            trackingMode: .duration
        )

        let recommendations = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [power, anchor, timed, valid]
        )

        #expect(catalogIDs(recommendations) == ["valid"])
        #expect(recommendations[0].preserves.contains(.modality(.dynamicStrength)))
        #expect(recommendations[0].preserves.contains(.tracking(.reps)))
    }

    @Test func equipmentIsAnOptionalFilterRatherThanAScoreBonus() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let differentEquipment = item(
            catalogID: "cable",
            name: "Alpha Incline Cable Press",
            equipment: .cable
        )
        let sameEquipment = item(
            catalogID: "barbell",
            name: "Zulu Incline Barbell Press"
        )

        let unrestricted = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [sameEquipment, differentEquipment]
        )
        let cableOnly = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [sameEquipment, differentEquipment],
            availableEquipment: [.cable]
        )

        #expect(catalogIDs(unrestricted) == ["cable", "barbell"])
        #expect(catalogIDs(cableOnly) == ["cable"])
        #expect(unrestricted[0].changes.contains(
            .equipment(from: .barbell, to: .cable)
        ))
        #expect(unrestricted[1].changes == [.exerciseVariant])
    }

    @Test func excludesAnatomicallyAndStructurallyUnrelatedCandidates() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let curl = item(
            catalogID: "curl",
            familyID: "elbow-flexion",
            name: "Cable Curl",
            primaryMuscles: [.bicepsBrachii],
            secondaryMuscles: [],
            equipment: .cable,
            mechanic: .isolation,
            pattern: nil,
            direction: nil,
            laterality: .unilateral
        )

        #expect(ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [curl]
        ).isEmpty)
    }

    // MARK: - Structural ordering and tiers

    @Test func sameFamilyPreservationRanksAheadAndExplainsEquipmentChange() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let sameFamily = item(
            catalogID: "dumbbell",
            name: "Incline Dumbbell Press",
            equipment: .dumbbell
        )
        let sharedPrimary = item(
            catalogID: "machine",
            familyID: "chest-press",
            name: "Machine Chest Press",
            secondaryMuscles: [.triceps],
            equipment: .machine,
            direction: .horizontal
        )

        let recommendations = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [sharedPrimary, sameFamily]
        )

        #expect(catalogIDs(recommendations) == ["dumbbell", "machine"])
        #expect(recommendations[0].tier == .closest)
        #expect(recommendations[1].tier == .strong)
        #expect(recommendations[0].preserves.contains(.family))
        #expect(recommendations[0].preserves.contains(
            .movement(.init(pattern: .push, direction: .diagonal))
        ))
        #expect(recommendations[0].changes.contains(
            .equipment(from: .barbell, to: .dumbbell)
        ))
        #expect(recommendations[0].explanation.contains("Closest match."))
        #expect(recommendations[0].explanation.contains("Changes equipment"))
    }

    @Test func partialTierRemainsAvailableWithinTheSameWorkoutType() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let reciprocalRoles = item(
            catalogID: "partial",
            familyID: "elbow-extension",
            name: "Chest-Assisted Triceps Drill",
            primaryMuscles: [.triceps],
            secondaryMuscles: [.pectoralisMajorClavicular],
            equipment: .cable,
            pattern: .pull,
            direction: .horizontal,
            planes: [.transverse],
            laterality: .unilateral
        )

        let recommendation = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [reciprocalRoles]
        ).first

        #expect(recommendation?.tier == .partial)
        #expect(recommendation?.changes.contains(
            .laterality(from: .bilateral, to: .unilateral)
        ) == true)
        #expect(recommendation?.preserves.contains(.modality(.dynamicStrength)) == true)
        #expect(recommendation?.preserves.contains(.tracking(.reps)) == true)
    }

    @Test func missingFamiliesAreNotTreatedAsAnExactMatch() {
        let anchor = item(
            catalogID: nil,
            familyID: nil,
            name: "Custom Press"
        )
        let candidate = item(
            catalogID: "candidate",
            familyID: nil,
            name: "Another Custom Press"
        )

        let recommendation = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [candidate]
        ).first

        #expect(recommendation?.tier == .strong)
        #expect(recommendation?.preserves.contains(.family) == false)
    }

    @Test func comparableButDifferentLoadSemanticsRemainAnExplainedTradeoff() {
        let anchor = item(catalogID: "anchor", name: "Loaded Dip")
        let candidate = item(
            catalogID: "bodyweight-added",
            name: "Weighted Dip",
            loadMode: .bodyweightAdded
        )

        let recommendation = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [candidate]
        ).first

        #expect(recommendation?.tier == .closest)
        #expect(recommendation?.changes.contains(
            .loadMode(from: .external, to: .bodyweightAdded)
        ) == true)
        #expect(recommendation?.explanation.contains("load semantics") == true)
    }

    // MARK: - Personalization and stability

    @Test func structuralFitDominatesFavoriteAndHistory() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let structurallyCloser = item(
            catalogID: "closer",
            name: "Incline Dumbbell Press",
            equipment: .dumbbell
        )
        let familiarFavorite = item(
            catalogID: "familiar",
            familyID: "chest-press",
            name: "Favorite Machine Press",
            secondaryMuscles: [],
            equipment: .machine,
            direction: .horizontal,
            isFavorite: true
        )
        let history = [
            familiarFavorite.historyKey: ExerciseSubstitution.Familiarity(
                sessionCount: 1000,
                lastPerformedAt: Date(timeIntervalSince1970: 10000)
            ),
        ]

        let recommendations = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [familiarFavorite, structurallyCloser],
            familiarityByHistoryKey: history
        )

        #expect(catalogIDs(recommendations) == ["closer", "familiar"])
    }

    @Test func favoriteThenHistoryBreakOnlyExactStructuralTies() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let favorite = item(
            catalogID: "favorite",
            name: "Zulu Favorite Press",
            equipment: .dumbbell,
            isFavorite: true
        )
        let familiar = item(
            catalogID: "familiar",
            name: "Zulu Familiar Press",
            equipment: .dumbbell
        )
        let unfamiliar = item(
            catalogID: "unfamiliar",
            name: "Alpha Unfamiliar Press",
            equipment: .dumbbell
        )
        let history = [
            familiar.historyKey: ExerciseSubstitution.Familiarity(
                sessionCount: 100,
                lastPerformedAt: Date(timeIntervalSince1970: 20000)
            ),
        ]

        let recommendations = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [unfamiliar, familiar, favorite],
            familiarityByHistoryKey: history
        )

        #expect(catalogIDs(recommendations) == [
            "favorite",
            "familiar",
            "unfamiliar",
        ])
    }

    @Test func inputOrderCannotChangeStableRankingAndLimit() {
        let anchor = item(catalogID: "anchor", name: "Incline Bench Press")
        let alpha = item(
            catalogID: "alpha",
            name: "Alpha Press",
            equipment: .dumbbell
        )
        let beta = item(
            catalogID: "beta",
            name: "Beta Press",
            equipment: .dumbbell
        )
        let firstOrder = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [beta, alpha],
            limit: 1
        )
        let reverseOrder = ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [alpha, beta],
            limit: 1
        )

        #expect(catalogIDs(firstOrder) == ["alpha"])
        #expect(catalogIDs(reverseOrder) == ["alpha"])
        #expect(ExerciseSubstitution.rank(
            anchor: anchor,
            candidates: [alpha],
            limit: 0
        ).isEmpty)
    }

    @Test func activeExerciseSubjectUsesItsPickTimeSnapshot() {
        let sourceCatalogItemID = UUID()
        let sourceClassification = ExerciseClassification(
            equipment: .barbell,
            mechanic: .compound,
            trainingRole: .push,
            pattern: .push,
            direction: .diagonal,
            planes: [.sagittal],
            laterality: .bilateral
        )
        let source = Exercise(
            name: "Logged Incline Press",
            catalogItemID: sourceCatalogItemID,
            catalogID: "anchor",
            familyID: "incline-press",
            group: .chest,
            plannedWeight: 100,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .pectoralisMajorClavicular, role: .primary),
                .init(muscle: .triceps, role: .secondary),
            ]),
            classification: sourceClassification
        )
        let sourceCatalogRow = item(
            catalogID: "anchor",
            name: "Current Catalog Row"
        )
        sourceCatalogRow.id = sourceCatalogItemID
        let substitute = item(
            catalogID: "substitute",
            name: "Incline Dumbbell Press",
            equipment: .dumbbell
        )

        let recommendations = ExerciseSubstitution.rank(
            anchor: .init(source),
            candidates: [sourceCatalogRow, substitute]
        )

        #expect(catalogIDs(recommendations) == ["substitute"])
        #expect(recommendations[0].preserves.contains(
            .movement(.init(pattern: .push, direction: .diagonal))
        ))
    }
}

//
//  CatalogDraftValidationTests.swift
//  vivobodyTests
//
//  Characterizes custom-exercise draft validation, first-invalid navigation,
//  search-term normalization, and dependent selection normalization without
//  exercising SwiftData mutation or editor presentation.
//

import Testing
@testable import vivobody

@MainActor
struct CatalogDraftValidationTests {
    private func validDraft(name: String = "Incline Press") -> CatalogDraft {
        var draft = CatalogDraft.empty
        draft.name = name
        draft.muscleInvolvementSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorClavicular, role: .primary)
        ]).snapshot
        return draft
    }

    private func validation(
        _ draft: CatalogDraft,
        occupied: [String] = []
    ) -> CatalogDraftValidation {
        CatalogDraftValidation(draft: draft, occupiedSearchTerms: occupied)
    }

    @Test func validDraftExposesNormalizedSaveText() {
        var draft = validDraft(name: "  Incline   Press  \n")
        draft.aliasesInput = " IP,  Upper Chest Press, ip, , "

        let result = validation(draft)

        #expect(result.canSave)
        #expect(result.firstInvalidAnchor == nil)
        #expect(result.normalizedName == "Incline   Press")
        #expect(result.normalizedAliases == ["IP", "Upper Chest Press"])
    }

    @Test func firstInvalidAnchorKeepsEditorOrdering() {
        var draft = CatalogDraft.empty
        #expect(validation(draft).firstInvalidAnchor == .name)

        draft.name = "Incline Press"
        #expect(validation(draft).firstInvalidAnchor == .muscles)

        draft.muscleInvolvementSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorClavicular, role: .primary)
        ]).snapshot
        draft.pattern = nil
        #expect(validation(draft).firstInvalidAnchor == .movementPattern)

        draft.pattern = .push
        draft.direction = nil
        #expect(validation(draft).firstInvalidAnchor == .direction)

        draft.direction = .horizontal
        draft.loadMode = .bodyweightAdded
        draft.bodyweightFraction = 0
        #expect(validation(draft).firstInvalidAnchor == .loadMode)

        draft.loadMode = .external
        draft.aliasesInput = "Existing Alias"
        #expect(validation(draft, occupied: [" existing   alias "]).firstInvalidAnchor == .aliases)
    }

    @Test func muscleValidationRequiresPrimaryInBrowseGroup() {
        var draft = validDraft()
        draft.muscleInvolvementSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorClavicular, role: .secondary),
            .init(muscle: .deltoidAnterior, role: .primary),
        ]).snapshot

        #expect(!validation(draft).hasValidMuscleRoles)

        draft.muscleInvolvementSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorClavicular, role: .primary),
            .init(muscle: .deltoidAnterior, role: .secondary),
        ]).snapshot
        #expect(validation(draft).hasValidMuscleRoles)
    }

    @Test func searchTermsRejectInternalAndCatalogCollisions() {
        var draft = validDraft(name: "Incline Press")
        draft.aliasesInput = " incline   press "
        #expect(!validation(draft).hasUniqueSearchTerms)

        draft.aliasesInput = "Upper Press"
        #expect(!validation(draft, occupied: [" upper   PRESS "]).hasUniqueSearchTerms)

        draft.aliasesInput = "IP, Upper Press"
        #expect(validation(draft, occupied: ["Flat Press"]).hasUniqueSearchTerms)
    }

    @Test func loadValidationPreservesEquipmentAndFractionRules() {
        var draft = validDraft()

        draft.loadMode = .external
        draft.bodyweightFraction = 0
        #expect(validation(draft).hasValidLoadProfile)

        draft.bodyweightFraction = 0.5
        #expect(!validation(draft).hasValidLoadProfile)

        draft.loadMode = .bodyweightAdded
        #expect(validation(draft).hasValidLoadProfile)

        draft.bodyweightFraction = 0
        #expect(!validation(draft).hasValidLoadProfile)

        draft.equipment = .band
        draft.loadMode = .external
        #expect(!validation(draft).hasValidLoadProfile)

        draft.loadMode = .nonComparable
        #expect(validation(draft).hasValidLoadProfile)
    }

    @Test func planeDefensiveStateKeepsExistingAnchorBehavior() {
        var draft = validDraft()
        draft.planes = []

        let result = validation(draft)

        #expect(!result.hasMovementPlanes)
        #expect(!result.canSave)
        #expect(result.firstInvalidAnchor == nil)
    }

    @Test func muscleGroupSelectionClearsOnlyOnRealChange() {
        var draft = validDraft()
        let snapshot = draft.muscleInvolvementSnapshot

        draft.selectMuscleGroup(.chest)
        #expect(draft.muscleInvolvementSnapshot == snapshot)

        draft.selectMuscleGroup(.back)
        #expect(draft.group == .back)
        #expect(draft.muscleInvolvementSnapshot.isEmpty)
    }

    @Test func mechanicAndPatternSelectionsNormalizeDependencies() {
        var draft = validDraft()
        draft.direction = .diagonal

        draft.selectMechanic(.isolation)
        #expect(draft.pattern == nil)
        #expect(draft.direction == nil)

        draft.selectMechanic(.compound)
        #expect(draft.pattern == .push)
        #expect(draft.direction == .horizontal)

        draft.direction = .diagonal
        draft.selectPattern(.pull)
        #expect(draft.direction == .diagonal)

        draft.selectPattern(.hinge)
        #expect(draft.direction == nil)

        draft.selectPattern(.push)
        #expect(draft.direction == .horizontal)
    }

    @Test func modalityEquipmentAndLoadSelectionsNormalizeDependencies() {
        var draft = validDraft()

        draft.selectModality(.isometricStrength)
        #expect(draft.trackingMode == .duration)
        draft.selectModality(.power)
        #expect(draft.trackingMode == .reps)

        draft.bodyweightFraction = 0.65
        draft.selectEquipment(.band)
        #expect(draft.loadMode == .nonComparable)
        #expect(draft.bodyweightFraction == 0)

        draft.loadMode = .bodyweightAdded
        draft.bodyweightFraction = 0.65
        draft.selectEquipment(.abWheel)
        #expect(draft.loadMode == .nonComparable)
        #expect(draft.bodyweightFraction == 0)

        draft.selectLoadMode(.assistanceSubtracted)
        #expect(draft.bodyweightFraction == 1)
        draft.bodyweightFraction = 0.8
        draft.selectLoadMode(.bodyweightAdded)
        #expect(draft.bodyweightFraction == 0.8)
        draft.selectLoadMode(.external)
        #expect(draft.bodyweightFraction == 0)
    }

    @Test func appearanceNormalizationRemainsBandOnly() {
        var bandDraft = validDraft()
        bandDraft.equipment = .band
        bandDraft.loadMode = .bodyweightAdded
        bandDraft.bodyweightFraction = 0.5
        bandDraft.normalizeBandLoadForEditorPresentation()
        #expect(bandDraft.loadMode == .nonComparable)
        #expect(bandDraft.bodyweightFraction == 0)

        var abWheelDraft = validDraft()
        abWheelDraft.equipment = .abWheel
        abWheelDraft.loadMode = .external
        abWheelDraft.normalizeBandLoadForEditorPresentation()
        #expect(abWheelDraft.loadMode == .external)
    }
}

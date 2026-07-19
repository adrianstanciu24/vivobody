//
//  ExerciseClassificationSnapshotTests.swift
//  vivobodyTests
//
//  Guards movement-classification snapshots across catalog picks,
//  template drafts, logged exercises, renames, and fresh-copy paths,
//  including bundled-name fallback and honestly unknown rows.
//

import Testing
@testable import vivobody

@MainActor
struct ExerciseClassificationSnapshotTests {

    private func customItem(
        name: String = "Landmine Arc",
        equipment: Equipment = .other,
        mechanic: Mechanic = .compound,
        pattern: MovementPattern? = .push,
        direction: PushPullDirection? = .vertical,
        plane: MovementPlane = .transverse,
        laterality: Laterality = .unilateral
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            name: name,
            group: .shoulders,
            defaultWeight: 45,
            equipment: equipment,
            mechanic: mechanic,
            pattern: pattern,
            direction: direction,
            plane: plane,
            laterality: laterality,
            isUserCreated: true
        )
    }

    @Test func customItemSnapshotsThroughTemplateIntoExercise() {
        let item = customItem(
            equipment: .cable,
            mechanic: .isolation,
            pattern: nil,
            direction: nil,
            plane: .frontal,
            laterality: .unilateral
        )

        let draft = ExerciseDraft(from: item)
        let templateExercise = draft.makeTemplateExercise(sortOrder: 2)
        let exercise = Exercise(from: templateExercise)

        #expect(draft.classification == item.classification)
        #expect(templateExercise.classification == item.classification)
        #expect(exercise.classification == item.classification)
        #expect(exercise.classification?.pattern == nil)
        #expect(exercise.classification?.direction == nil)
    }

    @Test func draftPreservesIdentityModalityAndLoadSemantics() {
        let item = ExerciseCatalogItem(
            catalogID: "plank-fixture",
            name: "Plank Fixture",
            group: .core,
            defaultWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 0.65,
            defaultDuration: 45,
            equipment: .bodyweight,
            mechanic: .compound,
            pattern: .core,
            plane: .sagittal,
            laterality: .bilateral
        )

        let draft = ExerciseDraft(from: item)
        let templateExercise = draft.makeTemplateExercise(sortOrder: 0)
        let exercise = Exercise(from: templateExercise)

        #expect(draft.catalogID == item.catalogID)
        #expect(draft.modality == .isometricStrength)
        #expect(draft.loadMode == .bodyweightAdded)
        #expect(draft.bodyweightFraction == 0.65)
        #expect(templateExercise.catalogID == item.catalogID)
        #expect(templateExercise.modality == .isometricStrength)
        #expect(templateExercise.loadMode == .bodyweightAdded)
        #expect(templateExercise.bodyweightFraction == 0.65)
        #expect(exercise.catalogID == item.catalogID)
        #expect(exercise.modality == .isometricStrength)
        #expect(exercise.loadMode == .bodyweightAdded)
        #expect(exercise.bodyweightFraction == 0.65)
    }

    @Test func snapshotSurvivesCatalogAndExerciseRenames() {
        let item = customItem()
        let expected = item.classification
        let templateExercise = TemplateExercise(from: item, sortOrder: 0)

        item.name = "Catalog Name Changed"
        templateExercise.name = "Template Name Changed"
        let exercise = Exercise(from: templateExercise)
        exercise.name = "Logged Name Changed"

        #expect(templateExercise.classification == expected)
        #expect(exercise.classification == expected)
    }

    @Test func directCatalogPickSnapshotsClassification() {
        let item = customItem(
            name: "Bench Press",
            equipment: .cable,
            mechanic: .isolation,
            pattern: nil,
            direction: nil,
            plane: .transverse,
            laterality: .unilateral
        )
        let exercise = Exercise(from: item, sortOrder: 1)

        #expect(exercise.classification == item.classification)
        #expect(exercise.classification?.mechanic == .isolation)
        #expect(exercise.equipmentRaw == item.equipmentRaw)
        #expect(exercise.mechanicRaw == item.mechanicRaw)
        #expect(exercise.patternRaw == item.patternRaw)
        #expect(exercise.directionRaw == item.directionRaw)
        #expect(exercise.planeRaw == item.planeRaw)
        #expect(exercise.lateralityRaw == item.lateralityRaw)
    }

    @Test func freshCopyPreservesSnapshot() {
        let source = Exercise(from: customItem(), sortOrder: 3)
        source.name = "Renamed Before Copy"

        let copy = Exercise.freshCopy(of: source)

        #expect(copy.classification == source.classification)
        #expect(copy.equipmentRaw == source.equipmentRaw)
        #expect(copy.mechanicRaw == source.mechanicRaw)
        #expect(copy.patternRaw == source.patternRaw)
        #expect(copy.directionRaw == source.directionRaw)
        #expect(copy.planeRaw == source.planeRaw)
        #expect(copy.lateralityRaw == source.lateralityRaw)
    }

    @Test func warmUpIntentRoundTripsThroughDraftTemplateAndWorkout() {
        var draft = ExerciseDraft(
            name: "Bench Press",
            group: .chest,
            isPerSet: true,
            sets: [
                SetDraft(weight: 45, reps: 10, kind: .warmUp),
                SetDraft(weight: 135, reps: 8, kind: .working),
            ]
        )
        draft.plannedSets = 2
        let template = draft.makeTemplateExercise(sortOrder: 0)
        let workout = Exercise(from: template)

        #expect(template.orderedSets.map(\.kind) == [.warmUp, .working])
        #expect(workout.orderedSets.map(\.kind) == [.warmUp, .working])
        #expect(ExerciseDraft(from: template).sets.map(\.kind) == [.warmUp, .working])
    }

    @Test func bundledNamesFallbackWhileUnknownRowsStayUnknown() {
        let bundled = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        let unknown = Exercise(
            name: "Uncatalogued Movement",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        let bundledTemplate = TemplateExercise(
            name: "Bench Press",
            group: .chest,
            plannedWeight: 0
        )
        let unknownTemplate = TemplateExercise(
            name: "Uncatalogued Movement",
            group: .chest,
            plannedWeight: 0
        )

        #expect(bundled.equipmentRaw == nil)
        #expect(bundled.classification?.mechanic == .compound)
        #expect(bundled.classification?.direction == .horizontal)
        #expect(unknown.classification == nil)
        #expect(bundledTemplate.classification?.mechanic == .compound)
        #expect(unknownTemplate.classification == nil)
    }
}

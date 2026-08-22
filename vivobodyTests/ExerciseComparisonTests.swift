//
//  ExerciseComparisonTests.swift
//  vivobodyTests
//
//  Proves the catalog-only comparison model: effective volume applies
//  the exact SetStimulus modality/tracking gate, overlap and emphasis
//  stay factual, per-side anatomy keeps training volume separate from
//  stabilizer involvement, and authored direction facts remain visible
//  alongside movement and tracking semantics. Also guards the
//  comparison anatomy ramps staying distinct and the separate UI
//  identity palette retaining accessible contrast.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseComparisonTests {
    // MARK: - Fixtures

    /// Diagonal-push barbell press: upper chest primary, front delts
    /// and triceps assisting.
    private func makeInclineBench() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "incline-bench-press",
            familyID: "diagonal-push",
            name: "Incline Bench Press",
            group: .chest,
            defaultWeight: 115,
            trackingMode: .reps,
            modality: .dynamicStrength,
            loadMode: .external,
            equipment: .barbell,
            mechanic: .compound,
            trainingRole: .push,
            pattern: .push,
            direction: .diagonal,
            planes: [.sagittal],
            laterality: .bilateral,
            execution: ExecutionInstructions(
                startingPosition: "Lie on the incline bench with the bar racked above your shoulders.",
                movement: "Press the bar upward until your elbows are straight.",
                endpoint: "Finish with the bar above your upper chest.",
                returnPhase: "Lower the bar under control to your upper chest.",
                controlledJoints: "Keep your feet planted and your shoulders pulled back.",
                supportAndPosture: "Stay seated back against the bench with a slight arch.",
                disqualifyingCompensations: [
                    "Bouncing the bar off the chest turns the press into a rebound."
                ],
                sideOrDirection: nil
            ),
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .pectoralisMajorClavicular, role: .primary),
                .init(muscle: .deltoidAnterior, role: .secondary),
                .init(muscle: .triceps, role: .secondary),
            ])
        )
    }

    /// Vertical-push barbell press: front delts primary, upper chest
    /// demoted to secondary, plus a stabilizer the bench press does
    /// not list and an unvisualized deep-rotator stabilizer.
    private func makeOverheadPress() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "overhead-press",
            familyID: "vertical-push",
            name: "Overhead Press",
            group: .shoulders,
            defaultWeight: 95,
            trackingMode: .reps,
            modality: .dynamicStrength,
            loadMode: .external,
            equipment: .barbell,
            mechanic: .compound,
            trainingRole: .push,
            pattern: .push,
            direction: .vertical,
            planes: [.sagittal, .frontal],
            laterality: .bilateral,
            execution: ExecutionInstructions(
                startingPosition: "Stand with the bar at your collarbones and your feet under your hips.",
                movement: "Press the bar overhead until your elbows are straight.",
                endpoint: "Finish with the bar over the middle of your feet.",
                returnPhase: "Lower the bar under control to your collarbones.",
                controlledJoints: "Keep your ribs down and your knees unlocked.",
                supportAndPosture: "Stand tall without leaning back.",
                disqualifyingCompensations: [
                    "Pushing with the legs turns the press into a push press."
                ],
                sideOrDirection: nil
            ),
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .deltoidAnterior, role: .primary),
                .init(muscle: .pectoralisMajorClavicular, role: .secondary),
                .init(muscle: .triceps, role: .secondary),
                .init(muscle: .externalRotators, role: .stabilizer),
                .init(muscle: .piriformis, role: .stabilizer),
            ])
        )
    }

    /// Real catalog-shaped power work: a rep-tracked external load can
    /// earn a direct performance record, but none of these anatomical
    /// roles may become hypertrophy hard-set volume.
    private func makeLandminePowerTest() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "standing-single-arm-landmine-press-power-test",
            familyID: "landmine-press",
            name: "Standing Single-Arm Landmine Press Power Test",
            group: .shoulders,
            defaultWeight: 45,
            defaultReps: 3,
            trackingMode: .reps,
            modality: .power,
            loadMode: .external,
            equipment: .barbell,
            mechanic: .compound,
            trainingRole: .push,
            pattern: .push,
            direction: .diagonal,
            planes: [.sagittal],
            laterality: .unilateral,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .deltoidAnterior, role: .primary),
                .init(muscle: .triceps, role: .secondary),
                .init(muscle: .pectoralisMajorClavicular, role: .secondary),
                .init(muscle: .abs, role: .stabilizer),
            ])
        )
    }

    /// A duration-only isometric hold with no comparable load.
    private func makePlank() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "plank",
            familyID: "anti-extension",
            name: "Plank",
            group: .core,
            defaultWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .nonComparable,
            defaultDuration: 30,
            equipment: .bodyweight,
            mechanic: .isolation,
            trainingRole: .core,
            pattern: nil,
            direction: nil,
            planes: [.sagittal],
            laterality: .bilateral,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .abs, role: .primary),
            ])
        )
    }

    /// Real-world interval work: duration-tracked whole-body effort
    /// with authored anatomical roles, but no hypertrophy volume.
    private func makeConditioning() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "burpee",
            familyID: "locomotion",
            name: "Burpee",
            group: .legs,
            defaultWeight: 0,
            trackingMode: .duration,
            modality: .conditioning,
            loadMode: .nonComparable,
            equipment: .bodyweight,
            mechanic: .compound,
            trainingRole: .other,
            pattern: .locomotion,
            direction: nil,
            planes: [.sagittal],
            laterality: .bilateral,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .vasti, role: .primary),
                .init(muscle: .abs, role: .secondary),
                .init(muscle: .deltoidAnterior, role: .stabilizer),
            ])
        )
    }

    /// Duration-tracked mobility work with explicit prime and assisting
    /// anatomy. Those roles remain visible but must never enter the
    /// hard-set currency.
    private func makeMobility() -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: "half-kneeling-thoracic-rotation-mobility",
            familyID: "thoracic-rotation-mobility",
            name: "Half-Kneeling Thoracic Rotation",
            group: .core,
            defaultWeight: 0,
            trackingMode: .duration,
            modality: .mobility,
            loadMode: .nonComparable,
            defaultDuration: 30,
            equipment: .bodyweight,
            mechanic: .isolation,
            trainingRole: .core,
            pattern: nil,
            direction: nil,
            planes: [.transverse],
            laterality: .unilateral,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .obliques, role: .primary),
                .init(muscle: .abs, role: .secondary),
            ])
        )
    }

    private func delta(
        _ muscle: Muscle,
        in comparison: ExerciseComparison
    ) -> ExerciseComparison.MuscleDelta? {
        comparison.muscleDeltas.first { $0.muscle == muscle }
    }

    // MARK: - Picker purpose

    @Test func activeWorkoutPickerSuppressesLongFormComparison() {
        #expect(!ExercisePickerPurpose.addToActiveWorkout.allowsComparison)
        #expect(ExercisePickerPurpose.explore.allowsComparison)
        #expect(ExercisePickerPurpose.compare(
            anchorID: UUID(),
            anchorName: "Bench Press"
        ).allowsComparison)
    }

    // MARK: - Muscle deltas

    @Test func roleChangesAreAttributedToTheStrongerSide() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )

        let chest = delta(.pectoralisMajorClavicular, in: comparison)
        let chestChange = chest?.change
        let expectedChest: ExerciseComparison.MuscleChange =
            .roleChange(anchor: .primary, other: .secondary)
        #expect(chestChange == expectedChest)
        #expect(chest?.anchorVolumeCredit == 1)
        #expect(chest?.otherVolumeCredit == 0.5)

        let delts = delta(.deltoidAnterior, in: comparison)
        let deltsChange = delts?.change
        let expectedDelts: ExerciseComparison.MuscleChange =
            .roleChange(anchor: .secondary, other: .primary)
        #expect(deltsChange == expectedDelts)
        #expect(delts?.anchorVolumeCredit == 0.5)
        #expect(delts?.otherVolumeCredit == 1)
    }

    @Test func sharedAndExclusiveMusclesAreClassified() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )

        let triceps = delta(.triceps, in: comparison)
        let tricepsChange = triceps?.change
        let expectedTriceps: ExerciseComparison.MuscleChange = .shared(.secondary)
        #expect(tricepsChange == expectedTriceps)
        #expect(triceps?.anchorVolumeCredit == 0.5)
        #expect(triceps?.otherVolumeCredit == 0.5)

        let rotators = delta(.externalRotators, in: comparison)
        let rotatorsChange = rotators?.change
        let expectedRotators: ExerciseComparison.MuscleChange = .otherOnly(.stabilizer)
        #expect(rotatorsChange == expectedRotators)
        #expect(rotators?.anchorRole == nil)
        #expect(rotators?.otherRole == .stabilizer)
        // Stabilizers appear anatomically but earn no volume credit.
        #expect(rotators?.earnsVolumeInNeither == true)

        let changedMuscles = comparison.roleChanges.map(\.muscle)
        #expect(changedMuscles.count == 2)
        #expect(changedMuscles.contains(.deltoidAnterior))
        #expect(changedMuscles.contains(.pectoralisMajorClavicular))
        #expect(comparison.otherOnlyDeltas.map(\.muscle).contains(.externalRotators))
        #expect(comparison.anchorOnlyDeltas.isEmpty)
    }

    @Test func trainingOverlapCapturesSharedWorkAndChangingEmphasis() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )
        let overlap = comparison.trainingOverlap

        #expect(comparison.trainingVolumeAvailability == .both)
        #expect(Set(overlap.sharedMuscles) == Set([
            .pectoralisMajorClavicular,
            .deltoidAnterior,
            .triceps,
        ]))
        #expect(overlap.anchorEmphasizedMuscles == [.pectoralisMajorClavicular])
        #expect(overlap.otherEmphasizedMuscles == [.deltoidAnterior])
        #expect(overlap.sharedRegions == [.chest, .shoulders, .arms])
        #expect(overlap.anchorEmphasizedRegions == [.chest])
        #expect(overlap.otherEmphasizedRegions == [.shoulders])

        let samePrimary = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeInclineBench()
        )
        #expect(Set(samePrimary.trainingOverlap.sharedMuscles) == Set([
            .pectoralisMajorClavicular,
            .deltoidAnterior,
            .triceps,
        ]))
        #expect(samePrimary.roleChanges.isEmpty)
    }

    @Test func powerAndConditioningRolesNeverBecomeVolumeBearing() {
        let comparison = ExerciseComparison(
            anchor: makeLandminePowerTest(),
            other: makeConditioning()
        )

        #expect(comparison.trainingVolumeAvailability == .neither)
        for delta in comparison.muscleDeltas {
            #expect(delta.earnsVolumeInNeither)
        }
        #expect(comparison.nonVolumeDeltas.count == comparison.muscleDeltas.count)
        #expect(!comparison.stabilizerOnlyDeltas.map(\.muscle).contains(.deltoidAnterior))
        #expect(comparison.muscleDeltas.allSatisfy {
            $0.anchorVolumeCredit == 0 && $0.otherVolumeCredit == 0
        })

        let overlap = comparison.trainingOverlap
        #expect(overlap.sharedMuscles.isEmpty)
        #expect(overlap.anchorEmphasizedMuscles.isEmpty)
        #expect(overlap.otherEmphasizedMuscles.isEmpty)
        #expect(overlap.sharedRegions.isEmpty)
        #expect(overlap.anchorEmphasizedRegions.isEmpty)
        #expect(overlap.otherEmphasizedRegions.isEmpty)

        // Performance-record eligibility does not opt power into
        // hypertrophy volume.
        #expect(makeLandminePowerTest().performanceSemanticKind == .powerLoadAndReps)
    }

    @Test func durationTrackedIsometricRolesBecomeVolumeBearing() {
        let comparison = ExerciseComparison(
            anchor: makePlank(),
            other: makeConditioning()
        )

        #expect(comparison.trainingVolumeAvailability == .anchorOnly)
        let abs = delta(.abs, in: comparison)
        #expect(abs?.anchorRole == .primary)
        #expect(abs?.anchorVolumeCredit == 1)
        #expect(abs?.otherRole == .secondary)
        #expect(abs?.otherVolumeCredit == 0)
        #expect(comparison.trainingOverlap.anchorEmphasizedMuscles == [.abs])
        #expect(!comparison.anatomyChannels(
            for: .anchor,
            scope: .trainingVolume
        ).isEmpty)
    }

    @Test func mobilityRolesNeverBecomeVolumeBearing() {
        let comparison = ExerciseComparison(
            anchor: makeMobility(),
            other: makeConditioning()
        )

        #expect(comparison.trainingVolumeAvailability == .neither)
        let obliques = delta(.obliques, in: comparison)
        #expect(obliques?.anchorRole == .primary)
        #expect(obliques?.anchorVolumeCredit == 0)
        #expect(comparison.anatomyChannels(
            for: .anchor,
            scope: .trainingVolume
        ).isEmpty)
        #expect(!comparison.anatomyChannels(
            for: .anchor,
            scope: .allInvolvement
        ).isEmpty)
        #expect(comparison.trainingOverlap.sharedMuscles.isEmpty)
        #expect(comparison.trainingOverlap.anchorEmphasizedMuscles.isEmpty)
        #expect(comparison.trainingOverlap.otherEmphasizedMuscles.isEmpty)
    }

    @Test func mismatchedStrengthTrackingModesEarnNoVolume() {
        let dynamicDuration = makeInclineBench()
        dynamicDuration.trackingMode = .duration
        let isometricReps = makePlank()
        isometricReps.trackingMode = .reps

        let comparison = ExerciseComparison(
            anchor: dynamicDuration,
            other: isometricReps
        )

        #expect(comparison.trainingVolumeAvailability == .neither)
        #expect(comparison.muscleDeltas.allSatisfy {
            $0.anchorVolumeCredit == 0 && $0.otherVolumeCredit == 0
        })
        #expect(comparison.anatomyChannels(
            for: .anchor,
            scope: .trainingVolume
        ).isEmpty)
        #expect(comparison.anatomyChannels(
            for: .other,
            scope: .trainingVolume
        ).isEmpty)
    }

    @Test func volumeAvailabilityNamesOneEligibleSideHonestly() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeLandminePowerTest()
        )
        #expect(comparison.trainingVolumeAvailability == .anchorOnly)
    }

    // MARK: - Per-exercise anatomy

    @Test func perSideAnatomySeparatesVolumeFromAllInvolvement() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )

        let anchorVolume = comparison.anatomyChannels(
            for: .anchor,
            scope: .trainingVolume
        )
        #expect(anchorVolume["Pectoralis_Major_Clavicular_L"]?.intensity == 1)
        #expect(anchorVolume["Pectoralis_Major_Clavicular_L"]?.tint == .accent)
        #expect(anchorVolume["Deltoid_Anterior_R"]?.intensity == 0.5)
        #expect(anchorVolume["External_Rotators_R"] == nil)

        let otherVolume = comparison.anatomyChannels(
            for: .other,
            scope: .trainingVolume
        )
        #expect(otherVolume["Pectoralis_Major_Clavicular_L"]?.intensity == 0.5)
        #expect(otherVolume["Pectoralis_Major_Clavicular_L"]?.tint == .compare)
        #expect(otherVolume["Deltoid_Anterior_R"]?.intensity == 1)
        #expect(otherVolume["Infraspinatus_R"] == nil)

        let otherInvolvement = comparison.anatomyChannels(
            for: .other,
            scope: .allInvolvement
        )
        #expect(otherInvolvement["Infraspinatus_R"]?.intensity == 0.2)
        #expect(otherInvolvement["Infraspinatus_R"]?.tint == .compare)
        #expect(comparison.unvisualizedMuscles(
            for: .other,
            scope: .trainingVolume
        ).isEmpty)
        #expect(comparison.unvisualizedMuscles(
            for: .other,
            scope: .allInvolvement
        ) == [.piriformis])
    }

    @Test func nonVolumeModalitiesStillRetainTheirAnatomy() {
        let comparison = ExerciseComparison(
            anchor: makeLandminePowerTest(),
            other: makeConditioning()
        )

        #expect(comparison.anatomyChannels(
            for: .anchor,
            scope: .trainingVolume
        ).isEmpty)
        let involvement = comparison.anatomyChannels(
            for: .anchor,
            scope: .allInvolvement
        )
        #expect(involvement["Deltoid_Anterior_L"]?.intensity == 1)
        #expect(involvement["Rectus_Abdomini_L"]?.intensity == 0.2)
    }

    // MARK: - Classification rows

    @Test func movementRowsSurfaceExactlyTheDifferences() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )
        let rows = comparison.movementRows

        let pattern = rows.first { $0.label == "Pattern" }
        #expect(pattern?.anchorValue == "Diagonal Push")
        #expect(pattern?.otherValue == "Vertical Push")
        #expect(pattern?.differs == true)

        let planes = rows.first { $0.label == "Planes" }
        #expect(planes?.anchorValue == "Sagittal")
        #expect(planes?.otherValue == "Sagittal · Frontal")
        #expect(planes?.differs == true)

        let equipment = rows.first { $0.label == "Equipment" }
        #expect(equipment?.differs == false)

        // Both bilateral and equal: laterality stays out of the way,
        // matching MovementClassificationCard's hiding rule.
        #expect(!rows.contains { $0.label == "Laterality" })
    }

    @Test func movementRowsHandleIsolationAndUnilateralWork() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makePlank()
        )
        let rows = comparison.movementRows

        // The plank has no compound pattern: the row stays because the
        // anchor has one, with an honest placeholder on the other side.
        let pattern = rows.first { $0.label == "Pattern" }
        #expect(pattern?.otherValue == "Not applicable")

        // Isolation work surfaces its training role instead.
        let training = rows.first { $0.label == "Training" }
        #expect(training?.otherValue == "Core")
    }

    @Test func lateralityRowAppearsWhenEitherSideIsUnilateral() {
        let unilateral = ExerciseCatalogItem(
            catalogID: "landmine-press",
            familyID: "diagonal-push",
            name: "Landmine Press",
            group: .shoulders,
            defaultWeight: 45,
            trackingMode: .reps,
            modality: .dynamicStrength,
            loadMode: .external,
            equipment: .barbell,
            mechanic: .compound,
            trainingRole: .push,
            pattern: .push,
            direction: .diagonal,
            planes: [.sagittal],
            laterality: .unilateral,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .deltoidAnterior, role: .primary),
            ])
        )
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: unilateral
        )
        let row = comparison.movementRows.first { $0.label == "Laterality" }
        #expect(row?.anchorValue == "Bilateral")
        #expect(row?.otherValue == "Unilateral")
        #expect(row?.differs == true)
    }

    @Test func directionNoteSeparatesTravelDirectionFromPlanes() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )
        let note = comparison.directionNote
        #expect(note?.contains("Incline Bench Press is authored as diagonal") == true)
        #expect(note?.contains("Overhead Press is authored as vertical") == true)
        #expect(note?.contains("resistance or travel direction") == true)
        #expect(note?.contains("Anatomical planes") == true)

        #expect(ExerciseComparison(
            anchor: makePlank(),
            other: makeConditioning()
        ).directionNote == nil)
    }

    // MARK: - Tracking and progression

    @Test func trackingRowsReportRecordSemantics() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makePlank()
        )
        let rows = comparison.trackingRows

        let records = rows.first { $0.label == "Records" }
        #expect(records?.anchorValue == "Load × reps")
        #expect(records?.otherValue == "Time only")
        #expect(records?.differs == true)

        let measured = rows.first { $0.label == "Measured" }
        #expect(measured?.anchorValue == "Reps")
        #expect(measured?.otherValue == "Time")
    }

    @Test func progressionNoteFiresOnlyOnGenuineDifferences() {
        let loadableVsTimed = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makePlank()
        )
        #expect(
            loadableVsTimed.progressionNote
                == "Only Incline Bench Press has a comparable load axis; Plank has no honest load-progression record."
        )

        // A ranked duration hold vs unranked conditioning: same load
        // comparability, different record eligibility.
        let rankedVsUnranked = ExerciseComparison(
            anchor: makePlank(),
            other: makeConditioning()
        )
        #expect(
            rankedVsUnranked.progressionNote == "Only Plank earns performance records."
        )

        let twins = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )
        #expect(twins.progressionNote == nil)
    }

    // MARK: - Working/stabilizer split

    /// The stabilizer floor keeps non-volume involvement distinct from
    /// muscles that contribute hard-set volume. Incline vs. overhead works
    /// three muscles and only stabilizes two more, both exclusive to the press.
    @Test func stabilizerFloorSplitsOffTheWorkingRows() {
        let comparison = ExerciseComparison(
            anchor: makeInclineBench(),
            other: makeOverheadPress()
        )
        let stabilizers = comparison.stabilizerOnlyDeltas
        let expectedStabilizers: [Muscle] = [.externalRotators, .piriformis]
        #expect(stabilizers.map(\.muscle) == expectedStabilizers)
        #expect(stabilizers.allSatisfy {
            $0.anchorRole == nil && $0.otherRole == .stabilizer
        })

        let working = comparison.muscleDeltas.filter { !$0.earnsVolumeInNeither }
        #expect(working.count == 3)
        #expect(stabilizers.count + working.count == comparison.muscleDeltas.count)
    }

    // MARK: - Comparison color ramps

    @Test func defaultChannelsKeepTheAccentRamp() {
        let rgb = MuscleColor.rgb(
            for: MuscleMapChannels(intensity: 1),
            theme: .dark
        )
        #expect(abs(rgb.red - 1.00) < 0.02)
        #expect(abs(rgb.green - 0.48) < 0.02)
        #expect(abs(rgb.blue - 0.10) < 0.02)
    }

    @Test(arguments: [BodyModelTheme.dark, .light])
    func comparisonRampsAreDistinct(theme: BodyModelTheme) {
        let accent = MuscleColor.rgb(
            for: MuscleMapChannels(intensity: 1, tint: .accent),
            theme: theme
        )
        let compare = MuscleColor.rgb(
            for: MuscleMapChannels(intensity: 1, tint: .compare),
            theme: theme
        )
        // The second exercise's ramp is cool: blue-dominant, clearly
        // not the accent orange.
        #expect(compare.blue > compare.red)
        #expect(compare.blue > accent.blue + 0.2)
        #expect(compare != accent)
    }

    @Test func comparisonUILabelsMeetAAContrast() {
        let black = MuscleColor.RGB(red: 0, green: 0, blue: 0)
        let white = MuscleColor.RGB(red: 1, green: 1, blue: 1)

        for tint in [MuscleMapTint.accent, .compare] {
            let darkLabel = ExerciseComparisonPalette.labelRGB(
                for: tint,
                theme: .dark
            )
            let lightLabel = ExerciseComparisonPalette.labelRGB(
                for: tint,
                theme: .light
            )
            #expect(contrastRatio(darkLabel, black) >= 4.5)
            #expect(contrastRatio(lightLabel, white) >= 4.5)
        }
    }

    @Test func comparisonControlColorsMeetEnhancedContrast() {
        for tint in [MuscleMapTint.accent, .compare] {
            let fill = ExerciseComparisonPalette.controlFillRGB(for: tint)
            #expect(contrastRatio(
                fill,
                ExerciseComparisonPalette.controlForegroundRGB
            ) >= 7)
        }
    }

    private func contrastRatio(
        _ lhs: MuscleColor.RGB,
        _ rhs: MuscleColor.RGB
    ) -> Double {
        let first = relativeLuminance(lhs)
        let second = relativeLuminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func relativeLuminance(_ rgb: MuscleColor.RGB) -> Double {
        0.2126 * linearized(rgb.red)
            + 0.7152 * linearized(rgb.green)
            + 0.0722 * linearized(rgb.blue)
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

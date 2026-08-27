//
//  ExercisePresentationTests.swift
//  vivobodyTests
//
//  Guards the shared lifter-focused exercise vocabulary and semantic
//  load descriptions, including completion accessibility wording.
//

import Testing
@testable import vivobody

@MainActor
struct ExercisePresentationTests {
    @Test func customExerciseAuthoringExposesEverySupportedModality() {
        let choices = ExerciseModality.customExerciseChoices

        #expect(choices == [
            .dynamicStrength,
            .isometricStrength,
            .power,
        ])
        #expect(choices.map(\.displayName) == [
            "Strength · Reps",
            "Strength · Hold",
            "Power / Explosive",
        ])
        #expect(choices.map(\.requiredTrackingMode) == [.reps, .duration, .reps])
        #expect(choices.map(\.categoryDisplayName) == [
            "Strength",
            "Strength",
            "Power / Explosive",
        ])
        #expect(choices.map(\.measureDisplayName) == ["Reps", "Hold", "Reps"])
    }

    @Test func durationTerminologyFollowsModality() {
        #expect(ExerciseModality.isometricStrength.durationLabel == "Hold")
        #expect(ExerciseModality.dynamicStrength.durationLabel == "Time")
        #expect(ExerciseModality.power.durationLabel == "Time")
    }

    @Test func customExerciseAssistanceUsesConcreteAuthoringCopy() {
        let assistance = ExerciseLoadMode.assistanceSubtracted

        #expect(assistance.customExerciseChoiceName == "Assistance")
        #expect(
            assistance.customExerciseChoiceLabel
                == "Assistance · Assisted pull-up/chin-up machine"
        )
        #expect(ExerciseLoadMode.external.customExerciseChoiceLabel == "External Load")
    }

    @Test func durationRecordCopyMatchesWhatWasActuallyRanked() {
        #expect(
            ExerciseLoadMode.external.durationRecordDetail(modality: .isometricStrength)
                == "Longer at this load"
        )
        #expect(
            ExerciseLoadMode.bodyweightAdded.durationRecordDetail(modality: .isometricStrength)
                == "Longer at this load"
        )
        #expect(
            ExerciseLoadMode.nonComparable.durationRecordDetail(modality: .isometricStrength)
                == "Longest hold"
        )
    }

    @Test func summaryLoadsPreserveLoggedMeaning() {
        #expect(ExerciseLoadMode.external.summaryLoadLabel(45, unit: .lb) == "45 lb")
        #expect(ExerciseLoadMode.bodyweightAdded.summaryLoadLabel(0, unit: .lb) == "BW")
        #expect(ExerciseLoadMode.bodyweightAdded.summaryLoadLabel(25, unit: .lb) == "BW + 25 lb")
        #expect(ExerciseLoadMode.assistanceSubtracted.summaryLoadLabel(40, unit: .lb) == "40 lb assist")
        #expect(ExerciseLoadMode.assistanceSubtracted.summaryLoadLabel(0, unit: .lb) == "Unassisted")
        #expect(ExerciseLoadMode.nonComparable.summaryLoadLabel(20, unit: .lb) == "20 lb resistance")
    }

    @Test func summaryLoadRangesPreserveLoggedMeaning() {
        #expect(
            ExerciseLoadMode.bodyweightAdded.summaryLoadRangeLabel(10, 25, unit: .lb)
                == "BW + 10–25 lb"
        )
        #expect(
            ExerciseLoadMode.assistanceSubtracted.summaryLoadRangeLabel(20, 40, unit: .lb)
                == "20–40 lb assist"
        )
        #expect(
            ExerciseLoadMode.nonComparable.summaryLoadRangeLabel(10, 20, unit: .lb)
                == "10–20 lb resistance"
        )
    }

    @Test func completionAccessibilityDoesNotInventOrReverseLoad() {
        let bodyweight = ExerciseLoadMode.bodyweightAdded.completionAccessibilityLabel(
            reps: 8,
            loggedWeight: 0,
            unit: .lb
        )
        #expect(bodyweight == "8 reps at bodyweight")
        #expect(!bodyweight.contains("0"))

        let assisted = ExerciseLoadMode.assistanceSubtracted.completionAccessibilityLabel(
            reps: 8,
            loggedWeight: 40,
            unit: .lb
        )
        #expect(assisted == "8 reps with 40 pounds of assistance")
        #expect(!assisted.contains("at 40"))

        let resistance = ExerciseLoadMode.nonComparable.completionAccessibilityLabel(
            reps: 12,
            loggedWeight: 20,
            unit: .lb
        )
        #expect(resistance == "12 reps with 20 pounds of resistance")
    }
}

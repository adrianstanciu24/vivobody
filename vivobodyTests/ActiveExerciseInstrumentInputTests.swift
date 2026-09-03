//
//  ActiveExerciseInstrumentInputTests.swift
//  vivobodyTests
//
//  Characterizes the pure active-card presentation assembler across empty,
//  working, and completed exercises without constructing SwiftData models.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ActiveExerciseInstrumentInputTests {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    @Test func zeroSetExerciseKeepsBothRecoveryInputs() {
        let input = source(sets: [], activeSetID: nil).makeInput()

        #expect(input.identity.name == "Fixture")
        #expect(input.identity.sets.isEmpty)
        #expect(input.configuration.setCount == 0)
        #expect(input.configuration.setLegend == "SETS")
        #expect(input.configuration.removableSetID == nil)
        #expect(input.configuration.weightIncrement == nil)
        #expect(input.metric == .empty)
        #expect(!input.effortAction.showsRIRControl)
        #expect(input.effortAction.primaryAction == .addFirstSet)
    }

    @Test func activeSetStatusesRemovalAndNewestReadingStayDistinct() throws {
        let sets = [
            set(firstID, weight: 135, reps: 8, completed: true),
            set(secondID, weight: 140, reps: 7, completed: true),
            set(thirdID, weight: 145, reps: 6),
        ]
        let input = source(sets: sets, activeSetID: thirdID).makeInput()

        #expect(input.identity.sets.map(\.status) == [.completed, .completed, .current])
        #expect(input.identity.sets.map(\.canRemove) == [false, false, true])
        #expect(input.identity.sets[0].completedValue == "135 x 8")
        #expect(input.identity.sets[0].visibleReading == nil)
        #expect(input.identity.sets[1].completedValue == "140 x 7")
        #expect(input.identity.sets[1].visibleReading == "140 x 7")
        #expect(input.identity.sets[2].accessibilityValue == "Current")
        #expect(input.configuration.removableSetID == thirdID)
        #expect(try #require(input.configuration.weightIncrement).label == "5 lb")
    }

    @Test func pendingSetsRemainRemovableButMinusTargetsTheLastPendingSet() {
        let sets = [
            set(firstID, completed: true),
            set(secondID),
            set(thirdID),
        ]
        let input = source(sets: sets, activeSetID: secondID).makeInput()

        #expect(input.identity.sets.map(\.status) == [.completed, .current, .pending])
        #expect(input.identity.sets.map(\.canRemove) == [false, true, true])
        #expect(input.configuration.removableSetID == thirdID)
    }

    @Test func activeAndCompletedRepPhasesPreserveActionsAndTopReading() {
        let activeInput = source(
            sets: [set(firstID), set(secondID)],
            activeSetID: firstID
        ).makeInput()
        guard case let .complete(activeButton) = activeInput.effortAction.primaryAction else {
            Issue.record("Expected active completion action")
            return
        }
        #expect(activeButton.setID == firstID)
        #expect(activeButton.title == "Complete set")
        #expect(!activeButton.isLastSet)
        #expect(activeInput.effortAction.showsRIRControl)
        guard case let .reps(activeReps) = activeInput.metric else {
            Issue.record("Expected reps instrument")
            return
        }
        #expect(activeReps.phase == .active)

        let completedInput = source(
            sets: [
                set(firstID, weight: 135, reps: 8, completed: true),
                set(secondID, weight: 155, reps: 5, completed: true),
            ],
            activeSetID: nil
        ).makeInput()
        #expect(completedInput.effortAction.primaryAction == .exerciseComplete)
        #expect(!completedInput.effortAction.showsRIRControl)
        guard case let .reps(completedReps) = completedInput.metric,
              case let .completed(top) = completedReps.phase
        else {
            Issue.record("Expected completed reps instrument")
            return
        }
        #expect(!top.isUnloaded)
        #expect(top.weightText == "155 lb")
        #expect(top.repsText == "5")
    }

    @Test func resistanceStylesCoverEnteredBodyweightAndUnloadedWork() throws {
        let entered = try repsInstrument(
            from: source(loadMode: .external, tracksResistance: true)
                .makeInput()
        )
        #expect(entered.instrument.resistanceStyle == .enteredLoad)
        #expect(entered.instrument.loadInputLabel == "Weight")

        let bodyweight = try repsInstrument(
            from: source(loadMode: .bodyweightAdded, tracksResistance: true)
                .makeInput()
        )
        #expect(bodyweight.instrument.resistanceStyle == .bodyweightAdded)
        #expect(bodyweight.instrument.loadInputLabel == "Added load")

        let unloaded = try repsInstrument(
            from: source(loadMode: .nonComparable, tracksResistance: false)
                .makeInput()
        )
        #expect(unloaded.instrument.resistanceStyle == .unloaded)
        #expect(unloaded.instrument.loadText(for: 0) == "Not set")
        #expect(unloaded.instrument.resistanceAccessibilityValue(for: 0) == "Not set")

        let assistance = try repsInstrument(
            from: source(loadMode: .assistanceSubtracted, tracksResistance: true)
                .makeInput()
        )
        #expect(assistance.instrument.showsAssistanceDirection)
        #expect(assistance.instrument.loadInputLabel == "Assistance")
    }

    @Test func rirEligibilityRequiresLiveDynamicStrengthReps() {
        let dynamicReps = source(
            trackingMode: .reps,
            modality: .dynamicStrength
        ).makeInput()
        let acknowledgingReps = source(
            trackingMode: .reps,
            modality: .dynamicStrength,
            pendingCompletionSetID: firstID
        ).makeInput()
        let powerReps = source(
            trackingMode: .reps,
            modality: .power
        ).makeInput()
        let isometricDuration = source(
            trackingMode: .duration,
            modality: .isometricStrength
        ).makeInput()
        let completed = source(
            trackingMode: .reps,
            modality: .dynamicStrength,
            sets: [set(firstID, completed: true)],
            activeSetID: nil
        ).makeInput()

        #expect(dynamicReps.effortAction.showsRIRControl)
        #expect(acknowledgingReps.effortAction.showsRIRControl)
        if case let .complete(button) = acknowledgingReps.effortAction.primaryAction {
            #expect(button.isPending)
        } else {
            Issue.record("Expected pending completion action")
        }
        #expect(!powerReps.effortAction.showsRIRControl)
        #expect(!isometricDuration.effortAction.showsRIRControl)
        #expect(!completed.effortAction.showsRIRControl)
    }

    @Test func actionTitlesRemainPositionAndModalityAware() throws {
        let repFirst = try completionButton(
            from: source(
                sets: [set(firstID), set(secondID)],
                activeSetID: firstID
            ).makeInput()
        )
        let repLast = try completionButton(
            from: source(
                sets: [set(firstID, completed: true), set(secondID)],
                activeSetID: secondID
            ).makeInput()
        )
        let holdFirst = try completionButton(
            from: source(
                trackingMode: .duration,
                modality: .isometricStrength,
                sets: [set(firstID, duration: 30), set(secondID, duration: 30)],
                activeSetID: firstID
            ).makeInput()
        )
        let timeLast = try completionButton(
            from: source(
                trackingMode: .duration,
                modality: .power,
                sets: [set(firstID, duration: 30)],
                activeSetID: firstID
            ).makeInput()
        )

        #expect(repFirst.title == "Complete set")
        #expect(repLast.title == "Finish exercise")
        #expect(holdFirst.title == "Complete hold")
        #expect(timeLast.title == "Finish time")
    }

    @Test func durationInputKeepsHoldAndBodyweightLoadSemantics() throws {
        let activeInput = source(
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .bodyweightAdded,
            sets: [set(firstID, weight: 0, reps: 0, duration: 30)],
            activeSetID: firstID
        ).makeInput()
        let button = try completionButton(from: activeInput)
        #expect(button.accessibilityLabelOverride == "Hold 0:30, at bodyweight")
        guard case let .duration(activeDuration) = activeInput.metric else {
            Issue.record("Expected duration instrument")
            return
        }
        #expect(activeDuration.phase == .active)
        #expect(activeDuration.instrument.resistanceStyle == .bodyweightAdded)

        let completedInput = source(
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .bodyweightAdded,
            sets: [set(firstID, weight: 25, reps: 0, duration: 45, completed: true)],
            activeSetID: nil
        ).makeInput()
        guard case let .duration(completedDuration) = completedInput.metric,
              case let .completed(top) = completedDuration.phase
        else {
            Issue.record("Expected completed duration instrument")
            return
        }
        #expect(top.durationLabel == "Hold")
        #expect(top.timeText == "0:45")
        #expect(top.loadText == "BW + 25 lb")
        #expect(top.accessibilityLabel == "Hold 0:45, at bodyweight plus 25 pounds")
    }

    @Test func weightIncrementCyclesWithinTheSelectedUnit() throws {
        let input = source(unit: .kg, weightStep: 2.5).makeInput()
        let increment = try #require(input.configuration.weightIncrement)

        let expectedLabel = 2.5.formatted(
            .number.precision(.fractionLength(0 ... 2))
        ) + " kg"
        #expect(increment.label == expectedLabel)
        #expect(increment.next() == 5)
    }

    private func source(
        trackingMode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        tracksResistance: Bool = true,
        unit: WeightUnit = .lb,
        weightStep: Double = 5,
        sets: [ActiveExerciseSetSnapshot]? = nil,
        activeSetID: UUID? = nil,
        pendingCompletionSetID: UUID? = nil
    ) -> ActiveExerciseCardSource {
        let resolvedSets = sets ?? [set(firstID)]
        return ActiveExerciseCardSource(
            name: "Fixture",
            supersetTag: "A1",
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            tracksResistance: tracksResistance,
            unit: unit,
            weightStep: weightStep,
            isActivePage: true,
            scrubCancellationID: 7,
            orderedSets: resolvedSets,
            activeSetID: activeSetID ?? resolvedSets.first(where: { !$0.isCompleted })?.id,
            pendingCompletionSetID: pendingCompletionSetID
        )
    }

    private func set(
        _ id: UUID,
        weight: Double = 135,
        reps: Int = 8,
        duration: TimeInterval = 0,
        completed: Bool = false
    ) -> ActiveExerciseSetSnapshot {
        ActiveExerciseSetSnapshot(
            id: id,
            weight: weight,
            reps: reps,
            duration: duration,
            isCompleted: completed
        )
    }

    private func repsInstrument(
        from input: ActiveExerciseCardInput
    ) throws -> ActiveRepsInstrumentInput {
        guard case let .reps(reps) = input.metric else {
            Issue.record("Expected reps instrument")
            throw InstrumentInputError.unexpectedMetric
        }
        return reps
    }

    private func completionButton(
        from input: ActiveExerciseCardInput
    ) throws -> ActiveSetCompletionButtonInput {
        guard case let .complete(button) = input.effortAction.primaryAction else {
            Issue.record("Expected completion action")
            throw InstrumentInputError.unexpectedAction
        }
        return button
    }
}

private enum InstrumentInputError: Error {
    case unexpectedMetric
    case unexpectedAction
}

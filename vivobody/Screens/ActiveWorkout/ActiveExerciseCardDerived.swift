//
//  ActiveExerciseCardDerived.swift
//  vivobody
//
//  Derived/computed state for ActiveExerciseCard, extracted from the
//  main file: model-to-input assembly, set/index lookups, and display
//  bindings that convert at the UI boundary. Scrub bindings mutate the
//  active set immediately; their owner persists once the scrub settles.
//

import SwiftUI

extension ActiveExerciseCard {
    // MARK: - Derived

    var cardInput: ActiveExerciseCardInput {
        ActiveExerciseCardSource(
            name: exercise.name,
            supersetTag: session.supersetTag(for: exercise),
            trackingMode: exercise.trackingMode,
            modality: exercise.modality,
            loadMode: exercise.loadMode,
            tracksResistance: exercise.tracksResistance,
            unit: unit,
            weightStep: weightStep,
            isActivePage: isActive,
            scrubCancellationID: effectiveScrubCancellationID,
            orderedSets: sets.map { set in
                ActiveExerciseSetSnapshot(
                    id: set.id,
                    weight: exercise.trackedWeight(set.weight),
                    reps: set.reps,
                    duration: set.duration,
                    isCompleted: set.isCompleted
                )
            },
            activeSetID: session.activeSet(for: exercise)?.id,
            pendingCompletionSetID: pendingCompletionSetID
        )
        .makeInput()
    }

    var exerciseIndex: Int {
        session.orderedExercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
    }

    /// True when this card is the pager's current page. Gates the
    /// first-use scrub hint so only the on-screen hero nudges and
    /// wears chevrons — not the pre-mounted neighbor cards that the
    /// SwipePager keeps in the hierarchy.
    var isActive: Bool {
        exerciseIndex == session.activeExerciseIndex
    }

    var sets: [WorkoutSet] {
        exercise.orderedSets
    }

    var activeIndex: Int? {
        session.activeSetIndex(for: exercise)
    }

    func workoutSet(id: UUID) -> WorkoutSet? {
        sets.first(where: { $0.id == id })
    }

    var displayedWeight: Double {
        session.activeSet(for: exercise)?.weight ?? exercise.plannedWeight
    }

    var displayedReps: Int {
        session.activeSet(for: exercise)?.reps ?? exercise.plannedReps
    }

    /// Scrubbed in display units; converted to/from canonical lb at
    /// the binding boundary so callers never see kg.
    var weightDisplayBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(displayedWeight, unit: unit) },
            set: { newDisplay in
                guard acceptsScrubInput, session.completedAt == nil else { return }
                session.updateActiveWeight(
                    for: exercise,
                    weight: WeightFormatter.toCanonical(newDisplay, unit: unit)
                )
                hasPendingScrubChanges = true
            }
        )
    }

    /// Reps live as Int in the model but BareScrubber scrubs Double.
    var repsBinding: Binding<Double> {
        Binding(
            get: { Double(displayedReps) },
            set: { new in
                guard acceptsScrubInput, session.completedAt == nil else { return }
                session.updateActiveReps(for: exercise, reps: Int(new.rounded()))
                hasPendingScrubChanges = true
            }
        )
    }

    var displayedDuration: TimeInterval {
        session.activeSet(for: exercise)?.duration ?? exercise.plannedDuration
    }

    /// Hold length scrubbed in seconds (Double for BareScrubber),
    /// written back to the active set as a TimeInterval.
    var durationBinding: Binding<Double> {
        Binding(
            get: { displayedDuration },
            set: { new in
                guard acceptsScrubInput, session.completedAt == nil else { return }
                session.updateActiveDuration(for: exercise, duration: new)
                hasPendingScrubChanges = true
            }
        )
    }

    var showsRIRControl: Bool {
        cardInput.effortAction.showsRIRControl
    }

    var rirBinding: Binding<Int> {
        Binding(
            get: { session.activeSet(for: exercise)?.repsInReserve ?? 2 },
            set: {
                session.updateActiveRIR(for: exercise, rir: $0)
                saveActiveSessionChanges()
            }
        )
    }

    func adjustResistance(_ direction: AccessibilityAdjustmentDirection) {
        let adjustment: Double
        switch direction {
        case .increment: adjustment = weightStep
        case .decrement: adjustment = -weightStep
        @unknown default: return
        }
        let range = unit.strengthRange
        let current = weightDisplayBinding.wrappedValue
        weightDisplayBinding.wrappedValue = min(
            max(current + adjustment, range.lowerBound),
            range.upperBound
        )
        activeScrubDidEnd()
    }
}

//
//  ActiveExerciseCardDerived.swift
//  vivobody
//
//  Derived/computed state for ActiveExerciseCard, extracted from the
//  main file: the active-page flag, set/index lookups, the display
//  bindings (weight / reps / duration / RIR) that convert at the UI
//  boundary, and the complete-button title. Read-only views over the
//  struct's stored state.
//

import SwiftUI
import SwiftData

extension ActiveExerciseCard {
    // MARK: - Derived

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
                session.updateActiveWeight(
                    for: exercise,
                    weight: WeightFormatter.toCanonical(newDisplay, unit: unit)
                )
                saveActiveSessionChanges()
            }
        )
    }

    /// Reps live as Int in the model but BareScrubber scrubs Double.
    var repsBinding: Binding<Double> {
        Binding(
            get: { Double(displayedReps) },
            set: { new in
                session.updateActiveReps(for: exercise, reps: Int(new.rounded()))
                saveActiveSessionChanges()
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
                session.updateActiveDuration(for: exercise, duration: new)
                saveActiveSessionChanges()
            }
        )
    }

    /// Verb for the complete button — mode + position aware. Timed
    /// holds finish as "Finish hold"; reps finish as "Finish exercise."
    func completeTitle(isLastSet: Bool, isHold: Bool) -> String {
        if isLastSet {
            return isHold ? "Finish hold" : "Finish exercise"
        }
        return isHold ? "Complete hold" : "Complete set"
    }
}

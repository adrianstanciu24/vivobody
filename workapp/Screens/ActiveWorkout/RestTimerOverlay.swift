//
//  RestTimerOverlay.swift
//  workapp
//
//  Full-screen overlay that hosts the BreathingTimer between sets.
//  Identity-rotates on each rest so a fresh timer is constructed every
//  time (the BreathingTimer reads its duration at init and would
//  otherwise stick to a stale end time).
//

import SwiftUI

struct RestTimerOverlay: View {
    @Bindable var session: WorkoutSession

    /// Bumped each time a rest begins so the BreathingTimer inside is
    /// reconstructed with a fresh `duration` rather than reusing its
    /// stored `@State` from a previous rest.
    @State private var instanceID: Int = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            BreathingTimer(
                duration: max(1, session.restRemaining),
                nextSetLabel: nextSetLabel,
                onComplete: { session.skipRest() },
                onSkip:     { session.skipRest() },
                onExtend:   { seconds in session.didExtendRest(by: seconds) }
            )
            .id(instanceID)
        }
        // Bump the instance whenever a brand new rest BEGINS
        // (restStartedAt becomes a non-nil value), so the
        // BreathingTimer is rebuilt with the fresh remaining time.
        // We deliberately ignore transitions to nil — those happen
        // when rest is ending, and rebuilding the timer mid-dismiss
        // produces a 1-second flicker that masks the dismissal.
        .onChange(of: session.restStartedAt, initial: true) { _, new in
            if new != nil {
                instanceID += 1
            }
        }
    }

    private var nextSetLabel: String? {
        let exercises = session.orderedExercises
        guard session.activeExerciseIndex < exercises.count else { return nil }
        let exercise = exercises[session.activeExerciseIndex]
        guard let nextIndex = session.activeSetIndex(for: exercise) else {
            return "Exercise complete"
        }
        return "Set \(nextIndex + 1) of \(exercise.plannedSets) · \(exercise.name)"
    }
}

//
//  TodayStartControls.swift
//  vivobody
//
//  Today’s persistent workout controls. One prominent action reflects the
//  current state: resume an active session, start the sole fresh path, or open
//  the workout chooser for scheduled, repeat, and saved-template decisions.
//

import SwiftUI
import VivoKit

extension TodayScreen {
    /// The stable start position adapts only when Fresh is the sole path.
    /// Once history or a saved template provides a real choice, the chooser
    /// owns scheduled, Repeat, Fresh, and saved-template decisions.
    var startCTA: some View {
        let startsFreshDirectly = latestSession == nil && templates.isEmpty

        return PrimaryActionButton(
            title: startsFreshDirectly ? "Start Fresh Workout" : "Start Workout",
            icon: startsFreshDirectly ? "plus" : "chevron.up",
            inputLabels: startsFreshDirectly
                ? ["Start Fresh Workout", "Start Fresh", "New Workout"]
                : ["Start Workout", "Start", "Begin"],
            sound: .commit
        ) {
            if startsFreshDirectly {
                showFreshExercisePicker = true
            } else {
                showStartSheet = true
            }
        }
        .accessibilityIdentifier("todayStartWorkoutButton")
        .accessibilityHint(
            startsFreshDirectly
                ? "Opens the exercise picker for a fresh workout"
                : "Opens workout options"
        )
        .accessibilitySortPriority(100)
    }

    /// A running workout replaces every start path. Its clocks are system
    /// timer text, so they tick without re-rendering the Today screen.
    func activeWorkoutCTA(_ session: WorkoutSession) -> some View {
        PrimaryActionButton(
            title: session.isAllComplete ? "Finish Workout" : "Resume Workout",
            subtitle: activeWorkoutStatus(session),
            icon: "chevron.up",
            inputLabels: session.isAllComplete
                ? ["Finish Workout", "Finish", "Workout"]
                : ["Resume Workout", "Resume", "Workout"]
        ) {
            appState.workout.expandWorkout()
        }
        .accessibilityIdentifier("activeWorkoutResumeBar")
        .accessibilityHint(
            session.isAllComplete
                ? "Opens the workout to finish and save it"
                : "Opens the workout you have in progress"
        )
        .accessibilitySortPriority(100)
    }

    /// Elapsed time plus the one thing the workout is waiting on.
    func activeWorkoutStatus(_ session: WorkoutSession) -> Text {
        let elapsed = Text(
            timerInterval: min(session.startedAt, .now) ... Date.distantFuture,
            countsDown: false
        )
        if session.isAllComplete {
            return Text("\(elapsed)  ·  All sets logged")
        }
        if let deadline = session.restDeadline {
            let rest = Text(timerInterval: min(.now, deadline) ... deadline, countsDown: true)
            return Text("\(elapsed)  ·  Rest \(rest)")
        }
        let exercises = session.orderedExercises
        if exercises.indices.contains(session.activeExerciseIndex) {
            let exercise = exercises[session.activeExerciseIndex]
            if let next = session.activeSetIndex(for: exercise) {
                return Text("\(elapsed)  ·  Set \(next + 1) of \(exercise.orderedSets.count)")
            }
        }
        return elapsed
    }

    /// A draft waiting for the workout sheet to dismiss is already gone as
    /// far as the persistent bar is concerned.
    var barSession: WorkoutSession? {
        appState.workout.isDiscardPending ? nil : appState.workout.activeSession
    }

    /// An active workout always wins; otherwise one stable action either opens
    /// the sole fresh path or the chooser, where multiple paths get hierarchy.
    var pinnedStartBar: some View {
        Group {
            if let session = barSession {
                activeWorkoutCTA(session)
            } else {
                startCTA
            }
        }
        // Persistent navigation stays compact; accessibility labels remain full.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.sm)
    }

    /// The template due today, if Up Next resolved one. Keeping this adapter
    /// beside the start controls avoids leaking presentation into UpNext.
    func scheduledTemplate(in upNext: UpNext) -> WorkoutTemplate? {
        guard case let .scheduled(template, _, _) = upNext.kind else { return nil }
        return template
    }
}

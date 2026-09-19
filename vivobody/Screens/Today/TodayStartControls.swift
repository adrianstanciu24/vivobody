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

    /// A running workout replaces every start path. The clock lives here so
    /// its per-second update does not re-render the whole Today screen.
    func activeWorkoutCTA(_ session: WorkoutSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            PrimaryActionButton(
                title: session.isAllComplete ? "Finish Workout" : "Resume Workout",
                subtitle: activeWorkoutStatus(session, now: context.date),
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
        }
        .accessibilitySortPriority(100)
    }

    /// Elapsed time plus the one thing the workout is waiting on.
    func activeWorkoutStatus(_ session: WorkoutSession, now: Date) -> String {
        let elapsed = Self.elapsedText(session.startedAt, to: now)
        if session.isAllComplete {
            return "\(elapsed)  ·  All sets logged"
        }
        if session.isResting {
            let remaining = max(0, Int(session.restRemaining.rounded(.up)))
            return "\(elapsed)  ·  Rest \(Self.clockText(remaining))"
        }
        let exercises = session.orderedExercises
        if exercises.indices.contains(session.activeExerciseIndex) {
            let exercise = exercises[session.activeExerciseIndex]
            if let next = session.activeSetIndex(for: exercise) {
                return "\(elapsed)  ·  Set \(next + 1) of \(exercise.orderedSets.count)"
            }
        }
        return elapsed
    }

    static func elapsedText(_ start: Date, to now: Date) -> String {
        clockText(max(0, Int(now.timeIntervalSince(start))))
    }

    /// m:ss while a workout is under an hour, h:mm:ss once it is not.
    static func clockText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
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
        .background {
            LinearGradient(
                colors: [
                    Surface.background.opacity(0),
                    Surface.background.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    /// The template due today, if Up Next resolved one. Keeping this adapter
    /// beside the start controls avoids leaking presentation into UpNext.
    func scheduledTemplate(in upNext: UpNext) -> WorkoutTemplate? {
        guard case let .scheduled(template, _, _) = upNext.kind else { return nil }
        return template
    }
}

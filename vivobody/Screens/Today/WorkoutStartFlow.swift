//
//  WorkoutStartFlow.swift
//  vivobody
//
//  The start-workout presentation for every surface that offers a start.
//  Fresh opens the exercise picker directly while it is the only path;
//  history or a saved template makes it a choice, and the chooser opens.
//  Each choice runs after its sheet has fully dismissed, so the active
//  workout never presents over an outgoing sheet.
//

import SwiftData
import SwiftUI

extension View {
    /// Setting `isRequested` to true opens the start flow. The flow sets it
    /// back to false at once.
    func workoutStartFlow(
        isRequested: Binding<Bool>,
        workout: WorkoutSessionController,
        lastSession: WorkoutSession?,
        templates: [WorkoutTemplate],
        scheduledTemplate: WorkoutTemplate?
    ) -> some View {
        modifier(WorkoutStartFlow(
            isRequested: isRequested,
            workout: workout,
            lastSession: lastSession,
            templates: templates,
            scheduledTemplate: scheduledTemplate
        ))
    }
}

struct WorkoutStartFlow: ViewModifier {
    @Binding var isRequested: Bool
    let workout: WorkoutSessionController
    let lastSession: WorkoutSession?
    /// Pre-sorted with `inStartOrder`.
    let templates: [WorkoutTemplate]
    let scheduledTemplate: WorkoutTemplate?

    @State private var showStartSheet = false
    @State private var showFreshExercisePicker = false
    @State private var pendingStart: (() -> Void)?
    @State private var pendingFreshStart: (() -> Void)?

    static func startsFreshDirectly(lastSession: WorkoutSession?, templates: [WorkoutTemplate]) -> Bool {
        lastSession == nil && templates.isEmpty
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isRequested) { _, requested in
                guard requested else { return }
                isRequested = false
                if Self.startsFreshDirectly(lastSession: lastSession, templates: templates) {
                    showFreshExercisePicker = true
                } else {
                    showStartSheet = true
                }
            }
            .sheet(isPresented: $showStartSheet, onDismiss: runPendingStart) {
                StartWorkoutSheet(
                    lastSession: lastSession,
                    templates: templates,
                    scheduledTemplate: scheduledTemplate,
                    onSelect: queueStart
                )
            }
            .sheet(isPresented: $showFreshExercisePicker, onDismiss: runPendingFreshStart) {
                ExercisePickerSheet { item in
                    pendingFreshStart = {
                        workout.startFreshWorkout(with: item)
                    }
                }
            }
    }

    private func queueStart(_ intent: StartIntent) {
        switch intent {
        case .repeatLast:
            let last = lastSession
            pendingStart = { workout.startTodaysWorkout(basedOn: last) }
        case .fresh:
            if workout.activeSession != nil {
                pendingStart = { workout.expandWorkout() }
            } else {
                pendingStart = { showFreshExercisePicker = true }
            }
        case let .template(template):
            pendingStart = { workout.startWorkoutFromTemplate(template) }
        }
    }

    private func runPendingStart() {
        let action = pendingStart
        pendingStart = nil
        action?()
    }

    private func runPendingFreshStart() {
        let action = pendingFreshStart
        pendingFreshStart = nil
        action?()
    }
}

extension [WorkoutTemplate] {
    /// Most recently used first, then never-used templates in their Library
    /// order. A `@Query` sort cannot express this because `lastUsedAt` is
    /// optional.
    var inStartOrder: [WorkoutTemplate] {
        sorted { lhs, rhs in
            switch (lhs.lastUsedAt, rhs.lastUsedAt) {
            case let (l?, r?): l > r
            case (.some, .none): true
            case (.none, .some): false
            case (.none, .none): lhs.sortOrder < rhs.sortOrder
            }
        }
    }
}

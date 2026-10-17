//
//  AppIntentRouter.swift
//  vivobody
//
//  The single app-process entry point for App Intents. Foreground actions
//  (start today, start a template, open a template or exercise) wait in memory
//  until AppRoot attaches, so a cold launch still restores the active
//  workout before it acts. Background Complete Set does not wait for a
//  scene: it wires the shared main context itself, completes the set
//  without presenting the workout, and awaits external presentation.
//

import SwiftData
import UIKit
import VivoKit

@MainActor
final class AppIntentRouter {
    private let appState: AppState
    /// Nil only when storage is unavailable. The router then drops every
    /// action and entity queries return nothing, so a registered intent
    /// cannot reach a missing store.
    let container: ModelContainer?
    private var isAttached = false
    private var pendingActions: [IncomingAction] = []

    init(appState: AppState, container: ModelContainer?) {
        self.appState = appState
        self.container = container
    }

    /// The actions the shared VivoKit intents call through their dependency.
    var workoutIntentActions: WorkoutIntentActions {
        WorkoutIntentActions(
            startTodaysWorkout: { [self] in perform(.startTodaysWorkout) },
            completeActiveSet: { [self] in await completeActiveSetInBackground() }
        )
    }

    /// Route a foreground action. Before AppRoot attaches, actions keep their
    /// arrival order and run when `attach()` drains them.
    func perform(_ action: IncomingAction) {
        guard container != nil else { return }
        guard isAttached else {
            pendingActions.append(action)
            return
        }
        appState.workout.handle(action)
    }

    /// Called once AppRoot has wired the context and restored the active
    /// workout.
    func attach() {
        isAttached = true
        let actions = pendingActions
        pendingActions.removeAll()
        for action in actions {
            appState.workout.handle(action)
        }
    }

    /// Complete the active set from a Live Activity. The system can launch
    /// the app in the background for this, before any scene connects, and
    /// can suspend it as soon as this returns, so external presentation is
    /// published before returning.
    func completeActiveSetInBackground() async {
        guard let container else { return }
        let workout = appState.workout
        if workout.modelContext == nil {
            // AppRoot's environment context is this same main context, so a
            // scene that connects later adopts the restored session as is.
            workout.modelContext = container.mainContext
            workout.restoreActiveWorkoutIfNeeded()
        }
        workout.handle(.completeActiveSet)
        guard let context = workout.modelContext else { return }
        await SessionSideEffects.flushExternalPresentation(
            for: workout.activeSession,
            // Scene deactivation normally schedules the rest chime; a
            // background completion starts a rest after that moment passed.
            schedulingRestNotification: UIApplication.shared.applicationState != .active,
            in: context
        )
    }
}

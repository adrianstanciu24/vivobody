//
//  WorkoutSessionController+IncomingActions.swift
//  vivobody
//
//  The single dispatch boundary for IncomingAction values normalized from
//  URLs, Handoff, Spotlight, widgets, Siri, and App Intent mailboxes.
//

import Foundation
import SwiftData

extension WorkoutSessionController {
    func handle(_ action: IncomingAction) {
        AppDiagnostics.incomingActionReceived(kind: action.diagnosticKind)
        switch action {
        case let .openTab(tab):
            open(tab)
        case .resumeWorkout:
            appState?.selectedTab = .today
            expandIfActive()
        case .startTodaysWorkout:
            handleStartToday()
        case let .startTemplate(id):
            handleStartTemplate(id)
        case let .continueSession(id):
            continueWorkout(with: id)
        case let .showExercise(id):
            handleShowExercise(id)
        case .completeActiveSet:
            completeActiveSet()
        }
    }

    private func open(_ tab: AppTab) {
        if tab == .insights {
            appState?.presentInsights()
        } else {
            appState?.selectedTab = tab
        }
    }

    private func handleStartToday() {
        guard let context = availableStartContext() else { return }
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        if case let .scheduled(template, _, _) = UpNext.compute(
            templates: templates,
            sessions: [],
            load: appState?.analytics.load
        ).kind {
            startWorkoutFromTemplate(template)
            return
        }
        var latest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        latest.fetchLimit = 1
        startTodaysWorkout(basedOn: try? context.fetch(latest).first)
    }

    private func handleStartTemplate(_ id: UUID) {
        guard let context = availableStartContext() else { return }
        var descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let template = try? context.fetch(descriptor).first else {
            appState?.selectedTab = .library
            return
        }
        startWorkoutFromTemplate(template)
        appState?.selectedTab = .today
    }

    private func availableStartContext() -> ModelContext? {
        guard activeSession == nil else {
            isWorkoutExpanded = true
            return nil
        }
        return modelContext
    }

    private func handleShowExercise(_ id: UUID) {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<ExerciseCatalogItem>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let item = try? context.fetch(descriptor).first else {
            appState?.selectedTab = .library
            return
        }
        isWorkoutExpanded = false
        appState?.selectedTab = .library
        appState?.presentSpotlightExercise(item)
    }
}

//
//  ActiveSetCompletionCoordinator.swift
//  vivobody
//
//  Owns the cancelable acknowledgement and pager-route timeline for one set
//  tap. It sequences frozen input, a synchronous controller commit, and a
//  guarded route without owning analytics, persistence, or domain decisions.
//

import Foundation
import Observation

nonisolated struct ActiveSetCompletionIntent: Equatable {
    let sessionID: UUID
    let exerciseID: UUID
    let setID: UUID
    let personalRecordCandidate: LivePersonalRecordCandidate
}

@MainActor
struct ActiveSetCompletionActions {
    let commit: (ActiveSetCompletionIntent) -> ActiveSetCompletionResult
    let currentSelection: () -> Int
    let applyRoute: (ActiveSetCompletionRoute) -> Void
    let onCommitted: () -> Void

    init(
        commit: @escaping (ActiveSetCompletionIntent) -> ActiveSetCompletionResult,
        currentSelection: @escaping () -> Int,
        applyRoute: @escaping (ActiveSetCompletionRoute) -> Void,
        onCommitted: @escaping () -> Void = {}
    ) {
        self.commit = commit
        self.currentSelection = currentSelection
        self.applyRoute = applyRoute
        self.onCommitted = onCommitted
    }
}

nonisolated enum ActiveSetCompletionDelay: Equatable {
    case acknowledgement
    case route

    var duration: Duration {
        switch self {
        case .acknowledgement: .milliseconds(550)
        case .route: .milliseconds(300)
        }
    }
}

@MainActor
@Observable
final class ActiveSetCompletionCoordinator {
    typealias Sleep = @MainActor (ActiveSetCompletionDelay) async throws -> Void

    private(set) var pendingSetID: UUID?
    private(set) var acceptsInput = true

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let sleep: Sleep

    init(
        sleep: @escaping Sleep = { delay in
            try await Task.sleep(for: delay.duration)
        }
    ) {
        self.sleep = sleep
    }

    /// Closes the input gate before `prepare` invalidates coast, flushes the
    /// visible detent, and captures immutable tap-time values.
    func start(
        setID: UUID,
        prepare: () -> ActiveSetCompletionIntent,
        actions: ActiveSetCompletionActions
    ) {
        cancel()
        acceptsInput = false
        pendingSetID = setID
        let intent = prepare()
        let expectedGeneration = generation

        task = Task { @MainActor [weak self] in
            await self?.run(
                intent: intent,
                actions: actions,
                generation: expectedGeneration
            )
        }
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        pendingSetID = nil
        acceptsInput = true
    }

    private func run(
        intent: ActiveSetCompletionIntent,
        actions: ActiveSetCompletionActions,
        generation expectedGeneration: Int
    ) async {
        do {
            try await sleep(.acknowledgement)
        } catch {
            releaseIfCurrent(expectedGeneration)
            return
        }
        guard generation == expectedGeneration else { return }

        let result = actions.commit(intent)
        guard generation == expectedGeneration,
              case let .committed(completion) = result
        else {
            releaseIfCurrent(expectedGeneration)
            return
        }
        actions.onCommitted()
        guard generation == expectedGeneration else { return }

        let route = ActiveSetCompletionRoutePlanner.route(after: completion)
        switch route {
        case .stay, .immediate:
            releaseIfCurrent(expectedGeneration)
            actions.applyRoute(route)

        case let .guardedDelayed(targetIndex, playsHandoffFeedback):
            let selectionBeforeBeat = actions.currentSelection()
            releaseGateIfCurrent(expectedGeneration)
            do {
                try await sleep(.route)
            } catch {
                finishTaskIfCurrent(expectedGeneration)
                return
            }
            guard generation == expectedGeneration,
                  actions.currentSelection() == selectionBeforeBeat,
                  selectionBeforeBeat != targetIndex
            else {
                finishTaskIfCurrent(expectedGeneration)
                return
            }
            actions.applyRoute(
                .guardedDelayed(
                    targetIndex: targetIndex,
                    playsHandoffFeedback: playsHandoffFeedback
                )
            )
            finishTaskIfCurrent(expectedGeneration)
        }
    }

    private func releaseIfCurrent(_ expectedGeneration: Int) {
        releaseGateIfCurrent(expectedGeneration)
        finishTaskIfCurrent(expectedGeneration)
    }

    private func releaseGateIfCurrent(_ expectedGeneration: Int) {
        guard generation == expectedGeneration else { return }
        pendingSetID = nil
        acceptsInput = true
    }

    private func finishTaskIfCurrent(_ expectedGeneration: Int) {
        guard generation == expectedGeneration else { return }
        task = nil
    }
}

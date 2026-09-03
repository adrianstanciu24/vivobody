//
//  ExerciseEffort.swift
//  vivobody
//
//  Turns the per-set RIR readings into one actionable read for the
//  Exercise detail screen: how hard the lift is usually pushed, and
//  whether the last session earned a resistance progression. The copy
//  respects load polarity: ordinary work adds load, while assisted work
//  reduces assistance. Pure value types over the archive — no SwiftUI,
//  no persistence — so it can be unit-tested in isolation.
//
//  Only completed, positive-repetition `.dynamicStrength + .reps`
//  work carries RIR. Every reading is gated on the `rirLogged` flag so
//  a freshly-spawned set sitting at the default RIR 2 never
//  masquerades as a real rating. Report construction runs over the
//  immutable analytics replay; model-facing callers only build its snapshot.
//

import Foundation

/// What the recent effort says to do next on this lift.
nonisolated enum ProgressionVerdict: Hashable {
    /// Left reps in the tank and still finished everything — room to
    /// progress resistance in the direction defined by the load mode.
    case ready
    /// Trained to failure while performance slipped — back off.
    case grind
    /// Productive middle ground; nothing to flag.
    case push
    /// Not enough signal to say anything.
    case none

    /// The load-mode-aware action earned by a `.ready` verdict. Assisted
    /// work progresses by reducing assistance, not by adding it.
    func progressionAction(for loadMode: ExerciseLoadMode) -> String? {
        guard self == .ready else { return nil }
        return loadMode == .assistanceSubtracted
            ? "reduce assistance"
            : "add load"
    }

    /// One-line nudge for the Effort card. Nil for `.none`.
    func headline(for loadMode: ExerciseLoadMode) -> String? {
        switch self {
        case .ready:
            guard let action = progressionAction(for: loadMode) else { return nil }
            return "Ready · \(action)"
        case .grind: return "Grinding · hold or deload"
        case .push: return "Pushing"
        case .none: return nil
        }
    }
}

/// Aggregated RIR read for a single exercise across the archive.
nonisolated struct ExerciseEffortSummary: Hashable {
    /// Mean RIR over the most recent session's logged sets.
    let avgRIR: Double
    /// Mean RIR over every logged set in history.
    let lifetimeAvgRIR: Double
    /// Lifetime count of `rirLogged` sets — the sample size.
    let loggedSetCount: Int
    /// Logged sets in the most recent rated session.
    let lastSessionSetCount: Int
    /// The next-step recommendation.
    let verdict: ProgressionVerdict
}

@MainActor
extension [WorkoutSession] {
    /// Build an effort summary for one catalog exercise. Bundled IDs or
    /// the custom item's exact performance signature define the series;
    /// name-only rows are used only when no catalog identity exists.
    func effortSummary(for item: ExerciseCatalogItem) -> ExerciseEffortSummary? {
        AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: self)
        ).effortSummary(forHistoryKey: item.historyKey)
    }

    /// Convenience for tests and callers that intentionally only know a
    /// display name.
    func effortSummary(forExerciseNamed name: String) -> ExerciseEffortSummary? {
        AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: self)
        ).effortSummary(forExerciseNamed: name)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Build every stable exercise's effort report in one archive pass.
    /// A session contributes only its first eligible row for a history key,
    /// matching the focused query's long-standing duplicate-row behavior.
    func effortSummariesByHistoryKey(
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [String: ExerciseEffortSummary] {
        var instancesByHistoryKey:
            [String: [(date: Date, exercise: AnalyticsExerciseSnapshot)]] = [:]

        for session in sessions {
            guard !isCancelled() else { return [:] }
            var capturedHistoryKeys = Set<String>()
            for replay in session.exercises {
                guard !isCancelled() else { return [:] }
                let exercise = replay.exercise
                let historyKey = exercise.historyKey
                guard !capturedHistoryKeys.contains(historyKey),
                      Self.isEffortEligible(exercise)
                else { continue }
                capturedHistoryKeys.insert(historyKey)
                instancesByHistoryKey[historyKey, default: []].append(
                    (session.date, exercise)
                )
            }
        }

        var summaries: [String: ExerciseEffortSummary] = [:]
        summaries.reserveCapacity(instancesByHistoryKey.count)
        for (historyKey, instances) in instancesByHistoryKey {
            guard !isCancelled() else { return [:] }
            if let summary = Self.effortSummary(instances: instances) {
                summaries[historyKey] = summary
            }
        }
        return summaries
    }

    /// Build a single exercise's effort report from the immutable replay.
    /// The history key preserves bundled identity and custom-exercise
    /// performance signatures without retaining a catalog model.
    func effortSummary(
        forHistoryKey historyKey: String
    ) -> ExerciseEffortSummary? {
        effortSummariesByHistoryKey()[historyKey]
    }

    /// Pure name-only convenience retained for fixtures and legacy callers.
    func effortSummary(
        forExerciseNamed name: String
    ) -> ExerciseEffortSummary? {
        let key = name.exerciseIdentityName
        let instances: [(date: Date, exercise: AnalyticsExerciseSnapshot)] = sessions.compactMap { replay in
            guard let exercise = replay.exercises.lazy.map(\.exercise).first(where: {
                $0.name.exerciseIdentityName == key
                    && Self.isEffortEligible($0)
            }) else { return nil }
            return (date: replay.date, exercise: exercise)
        }
        return Self.effortSummary(instances: instances)
    }

    /// Build an effort summary for one exercise (`.reps` only). Nil
    /// when the lift carries fewer than three logged RIR readings —
    /// below that the average is too noisy to act on.
    private static func effortSummary(
        instances: [(date: Date, exercise: AnalyticsExerciseSnapshot)]
    ) -> ExerciseEffortSummary? {
        let instances = instances.sorted { $0.date > $1.date }

        guard !instances.isEmpty else { return nil }

        let allLogged = instances
            .flatMap(\.exercise.sets)
            .filter { $0.isAnalyticsEligible && $0.reps > 0 && $0.rirLogged }
        guard allLogged.count >= 3 else { return nil }
        let lifetimeAvg = mean(allLogged.map(\.repsInReserve))

        // Most recent session that actually rated any sets.
        guard let lastIndex = instances.firstIndex(where: {
            $0.exercise.sets.contains {
                $0.isAnalyticsEligible && $0.reps > 0 && $0.rirLogged
            }
        }) else { return nil }
        let last = instances[lastIndex].exercise
        let lastLogged = last.sets.filter {
            $0.isAnalyticsEligible && $0.reps > 0 && $0.rirLogged
        }
        let lastAvg = mean(lastLogged.map(\.repsInReserve))

        let completedAll = !last.sets.isEmpty && last.sets.allSatisfy(\.isCompleted)
        let priorIndex = lastIndex + 1
        let prior = instances.indices.contains(priorIndex) ? instances[priorIndex].exercise : nil

        let verdict = Self.verdict(
            last: last,
            lastAvg: lastAvg,
            completedAll: completedAll,
            prior: prior
        )

        return ExerciseEffortSummary(
            avgRIR: lastAvg,
            lifetimeAvgRIR: lifetimeAvg,
            loggedSetCount: allLogged.count,
            lastSessionSetCount: lastLogged.count,
            verdict: verdict
        )
    }

    // MARK: - Verdict

    private static func verdict(
        last: AnalyticsExerciseSnapshot,
        lastAvg: Double,
        completedAll: Bool,
        prior: AnalyticsExerciseSnapshot?
    ) -> ProgressionVerdict {
        // Grind: hammering to failure (mean RIR ~0) while the top set
        // regressed versus the prior session.
        if lastAvg <= 0.5, let prior, regressed(last: last, prior: prior) {
            return .grind
        }
        // Ready: reps left in reserve and the full plan completed.
        if lastAvg >= 2, completedAll {
            return .ready
        }
        return .push
    }

    /// True when `last`'s top set fell behind `prior`'s — lower
    /// effective resistance, or the same resistance for fewer reps.
    /// This preserves the inverse polarity of machine assistance.
    private static func regressed(
        last: AnalyticsExerciseSnapshot,
        prior: AnalyticsExerciseSnapshot
    ) -> Bool {
        let a = top(last)
        let b = top(prior)
        guard let lastLoad = a.load, let priorLoad = b.load else {
            // Relative markers can choose each session's representative
            // set, but cannot compare absolute bodyweight-dependent load
            // across sessions when either bodyweight snapshot is unknown.
            return false
        }
        if lastLoad < priorLoad { return true }
        if lastLoad == priorLoad, a.reps < b.reps { return true }
        return false
    }

    private static func top(
        _ exercise: AnalyticsExerciseSnapshot
    ) -> (load: Double?, reps: Int) {
        guard let set = exercise.representativeTopSet else { return (nil, 0) }
        return (
            exercise.effectiveLoad(loggedWeight: set.weight),
            set.reps
        )
    }

    private static func isEffortEligible(
        _ exercise: AnalyticsExerciseSnapshot
    ) -> Bool {
        exercise.modality == .dynamicStrength
            && exercise.loadMode.supportsLoadComparison
            && exercise.trackingMode == .reps
    }

    private static func mean(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

//
//  ExerciseEffort.swift
//  vivobody
//
//  Turns the per-set RIR readings into one actionable read for the
//  Exercise detail screen: how hard the lift is usually pushed, and
//  whether the last session earned the right to add load. Pure value
//  types over the archive — no SwiftUI, no persistence — so it can be
//  unit-tested in isolation.
//
//  Only `.reps` exercises carry RIR; timed holds are skipped. Every
//  reading is gated on the `rirLogged` flag so a freshly-spawned set
//  sitting at the default RIR 2 never masquerades as a real rating.
//

import Foundation

/// What the recent effort says to do next on this lift.
nonisolated enum ProgressionVerdict: Hashable {
    /// Left reps in the tank and still finished everything — room to
    /// add load.
    case ready
    /// Trained to failure while performance slipped — back off.
    case grind
    /// Productive middle ground; nothing to flag.
    case push
    /// Not enough signal to say anything.
    case none

    /// One-line nudge for the Effort card. Nil for `.none`.
    var headline: String? {
        switch self {
        case .ready: return "Ready · add load"
        case .grind: return "Grinding · hold or deload"
        case .push:  return "Pushing"
        case .none:  return nil
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

extension Array where Element == WorkoutSession {
    /// Build an effort summary for one exercise (matched by name,
    /// case-insensitive, `.reps` only). Nil when the lift carries
    /// fewer than three logged RIR readings — below that the average
    /// is too noisy to act on.
    func effortSummary(forExerciseNamed name: String) -> ExerciseEffortSummary? {
        let key = name.lowercased()

        // Newest-first list of this lift's appearances. Duration
        // exercises are excluded — they carry no RIR.
        let instances: [(date: Date, exercise: Exercise)] = self.compactMap { session in
            guard let ex = session.orderedExercises.first(where: {
                $0.name.lowercased() == key && $0.trackingMode == .reps
            }) else { return nil }
            return (session.completedAt ?? session.startedAt, ex)
        }
        .sorted { $0.date > $1.date }

        guard !instances.isEmpty else { return nil }

        let allLogged = instances
            .flatMap { $0.exercise.sets }
            .filter { $0.isCompleted && $0.rirLogged }
        guard allLogged.count >= 3 else { return nil }
        let lifetimeAvg = mean(allLogged.map(\.repsInReserve))

        // Most recent session that actually rated any sets.
        guard let lastIndex = instances.firstIndex(where: {
            $0.exercise.sets.contains { $0.isCompleted && $0.rirLogged }
        }) else { return nil }
        let last = instances[lastIndex].exercise
        let lastLogged = last.sets.filter { $0.isCompleted && $0.rirLogged }
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
        last: Exercise,
        lastAvg: Double,
        completedAll: Bool,
        prior: Exercise?
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

    /// True when `last`'s top set fell behind `prior`'s — lighter, or
    /// same weight for fewer reps.
    private static func regressed(last: Exercise, prior: Exercise) -> Bool {
        let a = top(last)
        let b = top(prior)
        if a.weight < b.weight { return true }
        if a.weight == b.weight, a.reps < b.reps { return true }
        return false
    }

    private static func top(_ ex: Exercise) -> (weight: Double, reps: Int) {
        let completed = ex.sets.filter(\.isCompleted)
        guard let set = completed.max(by: { lhs, rhs in
            if lhs.weight == rhs.weight { return lhs.reps < rhs.reps }
            return lhs.weight < rhs.weight
        }) else { return (0, 0) }
        return (set.weight, set.reps)
    }

    private func mean(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

//
//  ExerciseVolumeContribution.swift
//  vivobody
//
//  Per-exercise weekly hard-set contribution: how many effective sets
//  ONE exercise delivered to each involved muscle over the trailing
//  7-day window. Powers the "This week" card on ExerciseDetailScreen,
//  which joins these shares against the cached MuscleVolume weekly
//  totals to show what the exercise is doing for each muscle right now.
//
//  The computation reuses the shared SetStimulus currency directly, so
//  the card can never disagree with the Insights volume bars about what
//  "a set of work" is worth: only completed dynamic-strength reps and
//  completed isometric holds earn credit, RIR beyond 2 discounts, an
//  unlogged RIR stays neutral, and stabilizers earn nothing. Scoping to
//  a single exercise over a 7-day window keeps the pass bounded to the
//  most recent sessions, so it runs synchronously on MainActor without
//  touching the full-archive replay. Pure value-type output driven by
//  an injected clock, fully testable without a simulator.
//

import Foundation

/// One exercise's hard-set contribution per muscle over a fixed
/// trailing window.
struct ExerciseVolumeContribution: Hashable {
    /// A single muscle's share of the windowed work.
    struct MuscleShare: Identifiable, Hashable {
        var id: Muscle {
            muscle
        }

        let muscle: Muscle
        /// The muscle's role on the CURRENT catalog item. Optional
        /// because history may credit a muscle the involvement editor
        /// has since removed; such rows render without a role qualifier.
        let role: MuscleRole?
        /// Hard sets this exercise delivered to the muscle in the window.
        let sets: Double
    }

    /// Primaries first, then secondaries, each group by sets descending.
    let shares: [MuscleShare]
    /// Whole-exercise hard-set total across all credited muscles.
    let totalSets: Double

    /// Matches MuscleVolume's default 7-day window so the card and the
    /// weekly bars always describe the same span.
    static let window: TimeInterval = 7 * 86400

    /// Price the item's appearances across `sessions` inside the window
    /// ending at `now`. Returns nil when the window holds no
    /// volume-bearing work — non-volume modalities, anatomy-less custom
    /// exercises, and idle weeks all collapse to "no card".
    @MainActor
    static func compute(
        sessions: [WorkoutSession],
        item: ExerciseCatalogItem,
        now: Date = Date(),
        window: TimeInterval = window
    ) -> ExerciseVolumeContribution? {
        let cutoff = now.addingTimeInterval(-window)
        var totals: [Muscle: Double] = [:]

        for session in sessions {
            let date = session.completedAt ?? session.startedAt
            // Reports are snapshots "as of" now: future-dated sessions
            // cannot count as work already performed.
            guard date <= now, date >= cutoff else { continue }
            for exercise in session.orderedExercises where exercise.matchesCatalogItem(item) {
                for (muscle, sets) in SetStimulus.credit(for: exercise) {
                    totals[muscle, default: 0] += sets
                }
            }
        }

        let involvement = item.muscleInvolvement
        let shares = totals.compactMap { muscle, sets -> MuscleShare? in
            guard sets > 0 else { return nil }
            return MuscleShare(
                muscle: muscle,
                role: involvement.role(for: muscle),
                sets: sets
            )
        }
        .sorted { lhs, rhs in
            let lhsRank = roleRank(lhs.role)
            let rhsRank = roleRank(rhs.role)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.sets != rhs.sets { return lhs.sets > rhs.sets }
            return lhs.muscle.displayName < rhs.muscle.displayName
        }

        guard !shares.isEmpty else { return nil }
        return ExerciseVolumeContribution(
            shares: shares,
            totalSets: shares.reduce(0) { $0 + $1.sets }
        )
    }

    /// Primary rows lead; a muscle the current involvement no longer
    /// lists sorts last.
    private static func roleRank(_ role: MuscleRole?) -> Int {
        switch role {
        case .primary: 0
        case .secondary: 1
        case .stabilizer, nil: 2
        }
    }
}

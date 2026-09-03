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
//  unlogged RIR stays neutral, and stabilizers earn nothing. The pure
//  accumulator overload reuses already-priced snapshot work; the model
//  adapter only owns snapshot construction. Output is value-only and
//  driven by an injected clock.
//

import Foundation

/// One exercise's hard-set contribution per muscle over a fixed
/// trailing window.
nonisolated struct ExerciseVolumeContribution: Hashable {
    /// Role-free cached currency produced with the core analytics generation.
    /// Current catalog roles are deliberately applied only at presentation.
    struct RawContribution: Hashable {
        let setsByMuscle: [Muscle: Double]
    }

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
        compute(
            accumulator: AnalyticsAccumulator.replay(
                AnalyticsSnapshot(sessions: sessions)
            ),
            historyKey: item.historyKey,
            currentRoles: item.muscleInvolvement.roles,
            now: now,
            window: window
        )
    }

    /// Price one stable exercise identity from an immutable analytics replay.
    /// Historical credits come from the snapshot; current roles only label
    /// those shares, preserving removed muscles as roleless history.
    static func compute(
        accumulator: AnalyticsAccumulator,
        historyKey: String,
        currentRoles: [Muscle: MuscleRole],
        now: Date,
        window: TimeInterval = window
    ) -> ExerciseVolumeContribution? {
        let raw = rawContributionsByHistoryKey(
            accumulator: accumulator,
            now: now,
            window: window
        )[historyKey]
        return relabel(raw, currentRoles: currentRoles)
    }

    /// Index all exercise contributions while the shared accumulator is hot.
    /// This is the only archive traversal used by the core Exercise Detail
    /// payload; per-item reads later relabel one small muscle dictionary.
    static func rawContributionsByHistoryKey(
        accumulator: AnalyticsAccumulator,
        now: Date,
        window: TimeInterval = window,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [String: RawContribution] {
        let cutoff = now.addingTimeInterval(-window)
        var totalsByHistoryKey: [String: [Muscle: Double]] = [:]

        for session in accumulator.sessions {
            guard !isCancelled() else { return [:] }
            let date = session.date
            // Reports are snapshots "as of" now: future-dated sessions
            // cannot count as work already performed.
            guard date <= now, date >= cutoff else { continue }
            for exercise in session.exercises {
                guard !isCancelled() else { return [:] }
                let historyKey = exercise.exercise.historyKey
                for (muscle, sets) in exercise.byMuscle {
                    totalsByHistoryKey[historyKey, default: [:]][muscle, default: 0] += sets
                }
            }
        }

        return totalsByHistoryKey.compactMapValues { totals in
            let positive = totals.filter { $0.value > 0 }
            return positive.isEmpty
                ? nil
                : RawContribution(setsByMuscle: positive)
        }
    }

    /// Apply the catalog item's current role vocabulary to cached raw credit.
    /// Historical muscles removed from the item remain visible as roleless.
    static func relabel(
        _ raw: RawContribution?,
        currentRoles: [Muscle: MuscleRole]
    ) -> ExerciseVolumeContribution? {
        guard let raw else { return nil }
        let shares = raw.setsByMuscle.compactMap { muscle, sets -> MuscleShare? in
            guard sets > 0 else { return nil }
            return MuscleShare(
                muscle: muscle,
                role: currentRoles[muscle],
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

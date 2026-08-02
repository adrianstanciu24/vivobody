//
//  MovementComposition.swift
//  vivobody
//
//  How your working sets split across compound (multi-joint) and
//  isolation (single-joint) lifts — the "are you building around the
//  big basics or chasing the pump?" lens. Compound work drives
//  strength and systemic load; isolation work targets individual
//  muscles. Neither is right or wrong, but the balance tells you
//  what kind of training this really is.
//
//  Counts completed dynamic- and isometric-strength sets over a rolling
//  window (4 weeks by default, to read CURRENT emphasis). Conditioning
//  and mobility are excluded. Each exercise is
//  classified from its persisted pick-time snapshot, with bundled-name
//  fallback for older rows. Unknown exercises are bucketed as
//  `unclassifiedSets` and left out of the ratio and shares so the split
//  stays honest. Pure value-type computation on injected dates (see
//  `MovementCompositionTests`).
//

import Foundation

// MARK: - Split

nonisolated struct CompositionSplit: Hashable, Sendable {
    let compoundSets: Int
    let isolationSets: Int
    let unclassifiedSets: Int

    var classifiedTotal: Int { compoundSets + isolationSets }
    var totalSets: Int { classifiedTotal + unclassifiedSets }
    var hasData: Bool { classifiedTotal > 0 }

    /// How much of the eligible strength work can support the visible
    /// compound/isolation read. Keeping this separate from the split
    /// prevents a tiny classified minority from presenting as a
    /// confident 100% verdict.
    var classificationCoverage: Double {
        totalSets > 0 ? Double(classifiedTotal) / Double(totalSets) : 0
    }

    /// A handful of sets can hint at allocation, but should not wear
    /// the same certainty as a settled four-week block.
    var isEarlyRead: Bool { totalSets > 0 && totalSets < 6 }

    /// Count of completed sets for a mechanic (compound/isolation).
    /// Unclassified is not a `Mechanic` case and is read directly off
    /// the struct.
    func count(_ m: Mechanic) -> Int {
        switch m {
        case .compound:  return compoundSets
        case .isolation: return isolationSets
        }
    }

    /// Fraction (0…1) of classified sets in a mechanic. Zero when
    /// there's no classified data — unclassified sets never enter the
    /// denominator.
    func share(_ m: Mechanic) -> Double {
        classifiedTotal > 0 ? Double(count(m)) / Double(classifiedTotal) : 0
    }

    /// The mechanic carrying the most classified sets, or nil when
    /// there's no data. Ties resolve toward `.compound` so a 50/50
    /// split never reads as "isolation-heavy."
    var dominant: Mechanic? {
        guard hasData else { return nil }
        return compoundSets >= isolationSets ? .compound : .isolation
    }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
    /// Compound-vs-isolation distribution of completed strength sets
    /// over the trailing `window` (default 4 weeks) as of `now`.
    /// Sets from exercises without a persisted or bundled-name
    /// classification are bucketed as unclassified and excluded.
    func compoundIsolationSplit(
        window: TimeInterval = 28 * 86_400,
        now: Date = Date()
    ) -> CompositionSplit {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: self)
        ).compoundIsolationSplit(window: window, now: now)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Snapshot-backed movement split used by the background
    /// analytics worker.
    func compoundIsolationSplit(
        window: TimeInterval = 28 * 86_400,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> CompositionSplit {
        let cutoff = now.addingTimeInterval(-window)
        var compound = 0, isolation = 0, unclassified = 0

        sessionLoop: for session in sessions {
            guard !isCancelled() else { break }
            let date = session.date
            guard date > cutoff, date <= now else { continue }
            for replay in session.exercises
            where replay.exercise.modality.supportsHardSetAnalytics {
                guard !isCancelled() else { break sessionLoop }
                let exercise = replay.exercise
                let completed = exercise.completedHardSetCount
                guard completed > 0 else { continue }
                guard let mechanic = exercise.classification?.mechanic else {
                    unclassified += completed
                    continue
                }
                switch mechanic {
                case .compound:  compound += completed
                case .isolation: isolation += completed
                }
            }
        }

        return CompositionSplit(
            compoundSets: compound,
            isolationSets: isolation,
            unclassifiedSets: unclassified
        )
    }
}

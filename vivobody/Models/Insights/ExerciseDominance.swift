//
//  ExerciseDominance.swift
//  vivobody
//
//  The "where does your recent work go?" lens for the Insights tab.
//  It ranks individual lifts by their share of completed working sets
//  over the trailing four weeks, so heavy and light exercises use the
//  same honest unit instead of tonnage favoring squats and deadlifts.
//
//  Dynamic-strength rep sets and isometric-strength timed sets count;
//  power, mismatched, incomplete, and empty sets do not. Exercises are
//  grouped by copied catalog identity, falling back to normalized
//  name for custom history.
//
//  Pure value-type computation on injected dates, so it's testable
//  on a virtual clock (see `ExerciseDominanceTests`).
//

import Foundation

// MARK: - Stat

/// One exercise's recent allocation: its identity, completed working
/// set count, and share of all qualifying sets (`0…1`).
nonisolated struct ExerciseDominanceStat: Identifiable, Hashable {
    var id: String {
        historyKey
    }

    let historyKey: String
    /// The exercise name (original casing from first sighting).
    let name: String
    let group: MuscleGroup
    let sets: Int
    let share: Double
}

// MARK: - Board

/// Ranked recent working-set allocation plus concentration reads.
nonisolated struct ExerciseDominanceBoard {
    /// All tracked exercises sorted by completed set count.
    let stats: [ExerciseDominanceStat]
    let totalSets: Int

    /// The single lift receiving the most recent sets.
    var top: ExerciseDominanceStat? {
        stats.first
    }

    /// Share of qualifying sets held by the #1 lift, `0…1`.
    var topShare: Double {
        top?.share ?? 0
    }

    /// Combined share of the top two lifts, `0…1`. The "are two
    /// lifts doing half the work?" headline read.
    var topTwoShare: Double {
        stats.prefix(2).reduce(0) { $0 + $1.share }
    }

    /// Whether any qualifying strength sets have been logged.
    var hasAny: Bool {
        !stats.isEmpty
    }
}

// MARK: - Aggregation

@MainActor
extension [WorkoutSession] {
    /// Completed working-set share per exercise over the trailing
    /// `window`, ranked descending. Uses the same four-week default as
    /// the exercise-type split shown alongside it.
    func exerciseDominance(
        window: TimeInterval = 28 * 86400,
        now: Date = Date()
    ) -> ExerciseDominanceBoard {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: self)
        ).exerciseDominance(window: window, now: now)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Snapshot-backed allocation used by the background analytics
    /// worker. No SwiftData model crosses into this computation.
    func exerciseDominance(
        window: TimeInterval = 28 * 86400,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> ExerciseDominanceBoard {
        let cancelled = ExerciseDominanceBoard(stats: [], totalSets: 0)
        guard !isCancelled() else { return cancelled }

        let cutoff = now.addingTimeInterval(-window)

        // Bucket keyed by stable identity; preserves the first-seen
        // display name and the muscle group.
        guard let byExercise = dominanceBuckets(
            after: cutoff,
            through: now,
            isCancelled: isCancelled
        ) else { return cancelled }

        let totalSets = byExercise.values.reduce(0) { $0 + $1.sets }
        guard totalSets > 0 else {
            return ExerciseDominanceBoard(stats: [], totalSets: 0)
        }

        var stats = Self.dominanceStats(byExercise, totalSets: totalSets)
        guard !isCancelled() else { return cancelled }
        stats.sort(by: Self.ranksBefore)
        guard !isCancelled() else { return cancelled }

        return ExerciseDominanceBoard(stats: stats, totalSets: totalSets)
    }

    private func dominanceBuckets(
        after cutoff: Date,
        through now: Date,
        isCancelled: @Sendable () -> Bool
    ) -> [String: (display: String, group: MuscleGroup, sets: Int)]? {
        var buckets: [String: (display: String, group: MuscleGroup, sets: Int)] = [:]
        for session in sessions where session.date > cutoff && session.date <= now {
            guard !isCancelled() else { return nil }
            for replay in session.exercises where replay.exercise.modality.supportsHardSetAnalytics {
                guard !isCancelled() else { return nil }
                guard accumulateDominance(
                    replay.exercise,
                    buckets: &buckets,
                    isCancelled: isCancelled
                ) else { return nil }
            }
        }
        return buckets
    }

    private func accumulateDominance(
        _ exercise: AnalyticsExerciseSnapshot,
        buckets: inout [String: (display: String, group: MuscleGroup, sets: Int)],
        isCancelled: @Sendable () -> Bool
    ) -> Bool {
        guard let count = Self.eligibleSetCount(exercise, isCancelled: isCancelled) else { return false }
        guard count > 0 else { return true }
        let key = exercise.historyKey
        if var bucket = buckets[key] {
            bucket.sets += count
            buckets[key] = bucket
            return true
        }
        let metadata = exerciseMetadata[key]
        buckets[key] = (
            display: metadata?.name ?? exercise.name,
            group: metadata?.group ?? exercise.group,
            sets: count
        )
        return true
    }

    private static func eligibleSetCount(
        _ exercise: AnalyticsExerciseSnapshot,
        isCancelled: @Sendable () -> Bool
    ) -> Int? {
        var count = 0
        for set in exercise.sets {
            guard !isCancelled() else { return nil }
            guard set.isAnalyticsEligible else { continue }
            let eligible = switch (exercise.modality, exercise.trackingMode) {
            case (.dynamicStrength, .reps): set.reps > 0
            case (.isometricStrength, .duration): set.duration > 0
            default: false
            }
            if eligible { count += 1 }
        }
        return count
    }

    private static func dominanceStats(
        _ buckets: [String: (display: String, group: MuscleGroup, sets: Int)],
        totalSets: Int
    ) -> [ExerciseDominanceStat] {
        buckets.map { key, bucket in
            ExerciseDominanceStat(
                historyKey: key,
                name: bucket.display,
                group: bucket.group,
                sets: bucket.sets,
                share: Double(bucket.sets) / Double(totalSets)
            )
        }
    }

    private static func ranksBefore(_ lhs: ExerciseDominanceStat, _ rhs: ExerciseDominanceStat) -> Bool {
        guard lhs.sets == rhs.sets else { return lhs.sets > rhs.sets }
        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard nameOrder == .orderedSame else { return nameOrder == .orderedAscending }
        return lhs.historyKey < rhs.historyKey
    }
}

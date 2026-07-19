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
//  conditioning, mobility, incomplete, and empty sets do not. Exercises
//  are grouped by copied catalog identity, falling back to normalized
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
    var id: String { historyKey }
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
    var top: ExerciseDominanceStat? { stats.first }
    /// Share of qualifying sets held by the #1 lift, `0…1`.
    var topShare: Double { top?.share ?? 0 }
    /// Combined share of the top two lifts, `0…1`. The "are two
    /// lifts doing half the work?" headline read.
    var topTwoShare: Double { stats.prefix(2).reduce(0) { $0 + $1.share } }
    /// Whether any qualifying strength sets have been logged.
    var hasAny: Bool { !stats.isEmpty }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Completed working-set share per exercise over the trailing
    /// `window`, ranked descending. Uses the same four-week default as
    /// the exercise-type split shown alongside it.
    func exerciseDominance(
        window: TimeInterval = 28 * 86_400,
        now: Date = Date()
    ) -> ExerciseDominanceBoard {
        let cutoff = now.addingTimeInterval(-window)

        // Bucket keyed by stable identity; preserves the first-seen
        // display name and the muscle group.
        var byExercise: [String: (display: String, group: MuscleGroup, sets: Int)] = [:]

        for session in self {
            let date = session.completedAt ?? session.startedAt
            guard date > cutoff, date <= now else { continue }

            for exercise in session.orderedExercises where exercise.modality.supportsHardSetAnalytics {
                let key = exercise.historyKey
                let sets = exercise.completedHardSetCount
                guard sets > 0 else { continue }

                if var bucket = byExercise[key] {
                    bucket.sets += sets
                    byExercise[key] = bucket
                } else {
                    byExercise[key] = (display: exercise.name, group: exercise.group, sets: sets)
                }
            }
        }

        let totalSets = byExercise.values.reduce(0) { $0 + $1.sets }
        guard totalSets > 0 else {
            return ExerciseDominanceBoard(stats: [], totalSets: 0)
        }

        let stats = byExercise
            .map { key, bucket -> ExerciseDominanceStat in
                ExerciseDominanceStat(
                    historyKey: key,
                    name: bucket.display,
                    group: bucket.group,
                    sets: bucket.sets,
                    share: Double(bucket.sets) / Double(totalSets)
                )
            }
            .sorted {
                if $0.sets == $1.sets {
                    let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
                    if nameOrder == .orderedSame {
                        return $0.historyKey < $1.historyKey
                    }
                    return nameOrder == .orderedAscending
                }
                return $0.sets > $1.sets
            }

        return ExerciseDominanceBoard(stats: stats, totalSets: totalSets)
    }
}

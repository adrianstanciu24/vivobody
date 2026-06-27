//
//  ExerciseDominance.swift
//  vivobody
//
//  The "where does your tonnage actually live?" lens for the
//  Insights tab. Strength trajectories track per-lift progress;
//  muscle balance grades sets per region; this ranks individual
//  LIFTS by their share of lifetime volume (weight × reps) so the
//  one or two exercises carrying the bulk of the work — and the
//  long tail nobody touches — are obvious at a glance.
//
//  Currency is tonnage: `Σ weight × reps` over every completed
//  `.reps` set across the whole archive (no window — lifetime).
//  Timed holds (`.duration` mode) carry no weight×reps and are
//  excluded, same as `WorkoutSession.totalVolume`. Incomplete sets
//  are excluded. Exercises are grouped by name (case-insensitive,
//  first-seen original casing preserved for display), so "Bench
//  Press" and "bench press" log as one lift.
//
//  Pure value-type computation on injected dates, so it's testable
//  on a virtual clock (see `ExerciseDominanceTests`).
//

import Foundation

// MARK: - Stat

/// One exercise's lifetime tonnage rank: its name, muscle group,
/// accumulated volume (canonical lb), and share of the archive's
/// total tonnage (`0…1`).
nonisolated struct ExerciseDominanceStat: Identifiable, Hashable {
    /// The exercise name (original casing from first sighting) —
    /// also the SwiftUI identity.
    var id: String { name }
    let name: String
    let group: MuscleGroup
    let volume: Double      // lifetime tonnage, canonical lb
    let share: Double       // 0…1 of total tonnage
}

// MARK: - Board

/// The ranked leaderboard of exercise tonnage shares, plus the
/// aggregate headline reads the section view surfaces.
nonisolated struct ExerciseDominanceBoard {
    /// All tracked exercises sorted descending by volume.
    let stats: [ExerciseDominanceStat]
    /// Total tonnage across every stat (canonical lb).
    let totalVolume: Double

    /// The single lift carrying the most lifetime volume.
    var top: ExerciseDominanceStat? { stats.first }
    /// Share of total tonnage held by the #1 lift, `0…1`.
    var topShare: Double { top?.share ?? 0 }
    /// Combined share of the top two lifts, `0…1`. The "are two
    /// lifts doing half the work?" headline read.
    var topTwoShare: Double { stats.prefix(2).reduce(0) { $0 + $1.share } }
    /// Whether any reps-mode tonnage has been logged.
    var hasAny: Bool { !stats.isEmpty }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Lifetime tonnage share per exercise, ranked descending.
    /// Iterates every session, sums `weight × reps` over completed
    /// `.reps` sets, groups by exercise name (case-insensitive),
    /// and converts each lift's volume into a share of the total.
    /// `now` is accepted for API symmetry with the other stat
    /// aggregators; dominance is a lifetime (unwindowed) read, so
    /// `now` is unused.
    func exerciseDominance(now: Date = Date()) -> ExerciseDominanceBoard {
        // Bucket keyed by lowercased name; preserves the first-seen
        // original-cased display name and the muscle group.
        var byName: [String: (display: String, group: MuscleGroup, volume: Double)] = [:]

        for session in self {
            for exercise in session.orderedExercises where exercise.trackingMode == .reps {
                let key = exercise.name.lowercased()
                let volume = exercise.sets
                    .filter(\.isCompleted)
                    .reduce(0) { $0 + $1.weight * Double($1.reps) }
                guard volume > 0 else { continue }

                if var bucket = byName[key] {
                    bucket.volume += volume
                    byName[key] = bucket
                } else {
                    byName[key] = (display: exercise.name, group: exercise.group, volume: volume)
                }
            }
        }

        let totalVolume = byName.values.reduce(0) { $0 + $1.volume }
        guard totalVolume > 0 else {
            return ExerciseDominanceBoard(stats: [], totalVolume: 0)
        }

        let stats = byName
            .map { (_, bucket) -> ExerciseDominanceStat in
                ExerciseDominanceStat(
                    name: bucket.display,
                    group: bucket.group,
                    volume: bucket.volume,
                    share: bucket.volume / totalVolume
                )
            }
            .sorted { $0.volume > $1.volume }

        return ExerciseDominanceBoard(stats: stats, totalVolume: totalVolume)
    }
}

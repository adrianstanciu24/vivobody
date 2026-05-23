//
//  ExerciseProgress.swift
//  workapp
//
//  Computes per-exercise time series from archived sessions for the
//  Progress section on Me and the per-exercise detail chart.
//
//  Why not reuse the live PR detector in ActiveExerciseCard? That one
//  asks "does the set the user is about to complete BEAT history?"
//  This one asks the inverse — walking the whole archive in time
//  order, which sets BECAME PRs at the moment they were logged. Same
//  intuition, different shape: one is point-in-time vs history, the
//  other is sequential history vs running max.
//

import Foundation

/// One data point in an exercise's progress series — the best set
/// completed in a given session, plus that session's total volume
/// for the exercise.
struct ExerciseProgressPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let topWeight: Double
    let topReps: Int
    let totalVolume: Double

    /// True when this point set a NEW best top-weight at the time
    /// it was logged. Computed by walking points in chronological
    /// order with a running max — so the resulting flags match the
    /// celebration moments the user experienced live.
    var isWeightPR: Bool = false

    /// Estimated 1-rep max via the Epley formula. Surfaced as one
    /// of the chartable metrics on the detail screen — useful when
    /// the user varies reps across sessions and the raw top-weight
    /// curve oscillates more than the underlying strength trend.
    var estimated1RM: Double {
        guard topReps > 0 else { return 0 }
        return topWeight * (1.0 + Double(topReps) / 30.0)
    }
}

/// Aggregated progress data for a single exercise across the user's
/// entire archive.
struct ExerciseProgress: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let group: MuscleGroup
    let points: [ExerciseProgressPoint]

    /// The most recent point in the series. Used by the Me-tab row
    /// to surface "current top set" without the consumer having to
    /// know about sort order.
    var latest: ExerciseProgressPoint? { points.last }

    /// The all-time best weight across every logged session for
    /// this exercise. Surfaced as the "PR" headline.
    var bestWeight: Double {
        points.map(\.topWeight).max() ?? 0
    }

    /// Weight delta from the second-most-recent to the most-recent
    /// point. Drives the up/flat/down trend chip. Nil when there
    /// aren't yet two points to compare.
    var weightDelta: Double? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].topWeight - points[points.count - 2].topWeight
    }
}

extension Array where Element == WorkoutSession {
    /// Group archived sessions by exercise name and produce a
    /// chronological progress series for each. Only sessions with at
    /// least one completed set for the exercise contribute. Only
    /// exercises with ≥2 data points are returned — a single
    /// performance isn't a trend, and rendering a one-point line
    /// chart would just be a dot.
    ///
    /// Sorted descending by recency of the most recent data point,
    /// so the things the user has been working on lately come first.
    var progressByExercise: [ExerciseProgress] {
        // Tuple bucket (not a nested struct) — Swift doesn't allow
        // nested types in generic function bodies, and this lives
        // inside an extension on `Array where Element == ...`.
        var byName: [String: (group: MuscleGroup, points: [ExerciseProgressPoint])] = [:]

        for session in self {
            let date = session.completedAt ?? session.startedAt
            for exercise in session.orderedExercises {
                let completed = exercise.sets.filter(\.isCompleted)
                guard !completed.isEmpty else { continue }

                // Top set = heaviest weight, with reps as the
                // tiebreaker. Matches `WorkoutSession.topSet(for:)`.
                let top = completed.max { a, b in
                    if a.weight == b.weight { return a.reps < b.reps }
                    return a.weight < b.weight
                }!

                let totalVolume = completed.reduce(0.0) { $0 + $1.weight * Double($1.reps) }

                let point = ExerciseProgressPoint(
                    date: date,
                    topWeight: top.weight,
                    topReps: top.reps,
                    totalVolume: totalVolume
                )

                if var bucket = byName[exercise.name] {
                    bucket.points.append(point)
                    byName[exercise.name] = bucket
                } else {
                    byName[exercise.name] = (group: exercise.group, points: [point])
                }
            }
        }

        return byName
            .filter { $0.value.points.count >= 2 }
            .map { name, bucket in
                // Sort by date ASC then walk to mark weight PRs at
                // the moment they were achieved.
                let sorted = bucket.points.sorted { $0.date < $1.date }
                var runningMax: Double = -.infinity
                var flagged: [ExerciseProgressPoint] = []
                flagged.reserveCapacity(sorted.count)
                for var p in sorted {
                    if p.topWeight > runningMax {
                        p.isWeightPR = true
                        runningMax = p.topWeight
                    }
                    flagged.append(p)
                }
                return ExerciseProgress(name: name, group: bucket.group, points: flagged)
            }
            .sorted { (lhs, rhs) in
                let lDate = lhs.latest?.date ?? .distantPast
                let rDate = rhs.latest?.date ?? .distantPast
                return lDate > rDate
            }
    }
}

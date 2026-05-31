//
//  ExerciseProgress.swift
//  vivobody
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

    /// Longest completed hold (seconds) in the session, for
    /// `.duration` exercises. Zero for the reps case.
    var topDuration: TimeInterval = 0

    /// How the exercise is measured — decides which metric
    /// (`topWeight` vs `topDuration`) the charts and stats read.
    var trackingMode: TrackingMode = .reps

    let totalVolume: Double

    /// True when this point set a NEW best at the time it was logged
    /// on the mode's primary metric — top weight for `.reps`, longest
    /// hold for `.duration`. Computed by walking points in
    /// chronological order with a running max, so the flags match the
    /// PR moments the user experienced live.
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

    /// How this exercise is measured. Derived from its points (a
    /// single exercise has one consistent mode). Drives whether the
    /// progress UI reads weight or hold-time.
    var trackingMode: TrackingMode { points.first?.trackingMode ?? .reps }

    /// The most recent point in the series. Used by the Me-tab row
    /// to surface "current top set" without the consumer having to
    /// know about sort order.
    var latest: ExerciseProgressPoint? { points.last }

    /// The all-time best weight across every logged session for
    /// this exercise. Surfaced as the "PR" headline.
    var bestWeight: Double {
        points.map(\.topWeight).max() ?? 0
    }

    /// The all-time longest hold across every logged session —
    /// the `.duration` counterpart to `bestWeight`.
    var bestDuration: TimeInterval {
        points.map(\.topDuration).max() ?? 0
    }

    /// Weight delta from the second-most-recent to the most-recent
    /// point. Drives the up/flat/down trend chip. Nil when there
    /// aren't yet two points to compare.
    var weightDelta: Double? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].topWeight - points[points.count - 2].topWeight
    }

    /// Hold-time delta between the two most-recent points — the
    /// `.duration` counterpart to `weightDelta`.
    var durationDelta: TimeInterval? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].topDuration - points[points.count - 2].topDuration
    }
}

// MARK: - Last instance lookup

/// What the user did the last time they performed a given exercise.
/// Used by the ExercisePickerSheet rows to decorate each entry with
/// fresh context ("LAST · 145 lb × 8 · 3d ago") instead of just the
/// catalog's default values.
struct LastExerciseInstance: Hashable {
    /// Weight (canonical lb) of the representative top set in the
    /// most recent session that included this exercise.
    let topWeight: Double

    /// Reps of that top set.
    let topReps: Int

    /// Hold length (seconds) of that top set, for `.duration`
    /// exercises. Zero for the reps case.
    var topDuration: TimeInterval = 0

    /// How the exercise is measured — decides how `metricLabel`
    /// reads (weight × reps vs. a held interval).
    var trackingMode: TrackingMode = .reps

    /// Date the session was completed (or started, if completion
    /// timestamp is missing — defensive only, archived sessions
    /// always have completedAt set).
    let sessionDate: Date

    /// True when this top set matches the all-time best for the
    /// exercise on its mode's primary metric (weight, or longest
    /// hold). Lets the picker show a subtle "PR" indicator.
    let isAllTimeBest: Bool

    /// Mode-aware one-line metric for picker / detail decorations,
    /// matching `Exercise.setLabel`: "145 × 8" for reps, "0:45"
    /// (or "25 × 0:45" when loaded) for a hold.
    func metricLabel(unit: WeightUnit) -> String {
        switch trackingMode {
        case .reps:
            return "\(WeightFormatter.string(topWeight, unit: unit, includeUnit: false)) × \(topReps)"
        case .duration:
            let time = DurationFormatter.string(topDuration)
            guard topWeight > 0 else { return time }
            return "\(WeightFormatter.string(topWeight, unit: unit, includeUnit: false)) × \(time)"
        }
    }
}

extension Array where Element == WorkoutSession {
    /// Build a name → LastExerciseInstance lookup in one pass over
    /// the archive. Picker rows do O(1) lookups against this map
    /// instead of re-scanning history per row.
    ///
    /// Match is by exercise name (case-insensitive). Templates and
    /// active workouts already copy the name at pick-time, so equal
    /// strings imply equal lifts — same convention as
    /// `progressByExercise` above.
    func lastInstanceByExercise() -> [String: LastExerciseInstance] {
        // Step 1: gather every "top set per session per exercise"
        // tuple. The top set is mode-aware (heaviest for reps,
        // longest hold for duration) via `session.topSet(for:)`. The
        // arrays inside the dictionary are appended in archive order,
        // not by date — sorting comes next.
        var rawByName: [String: [(date: Date, top: WorkoutSet, mode: TrackingMode)]] = [:]

        for session in self {
            let date = session.completedAt ?? session.startedAt
            for exercise in session.orderedExercises {
                guard let top = session.topSet(for: exercise) else { continue }
                let key = exercise.name.lowercased()
                rawByName[key, default: []].append((date: date, top: top, mode: exercise.trackingMode))
            }
        }

        // Step 2: for each exercise, find the most recent session's
        // top set AND the all-time best, compared on the mode's
        // primary metric. Two separate scans on a small list.
        var result: [String: LastExerciseInstance] = [:]
        for (name, entries) in rawByName {
            guard let mostRecent = entries.max(by: { $0.date < $1.date }) else { continue }
            let mode = mostRecent.mode
            let isBest: Bool
            switch mode {
            case .reps:
                let allTimeBest = entries.map(\.top.weight).max() ?? 0
                isBest = mostRecent.top.weight >= allTimeBest
            case .duration:
                let allTimeBest = entries.map(\.top.duration).max() ?? 0
                isBest = mostRecent.top.duration >= allTimeBest
            }
            result[name] = LastExerciseInstance(
                topWeight: mostRecent.top.weight,
                topReps: mostRecent.top.reps,
                topDuration: mostRecent.top.duration,
                trackingMode: mode,
                sessionDate: mostRecent.date,
                isAllTimeBest: isBest
            )
        }
        return result
    }
}

// MARK: - Relative date

/// Compact relative-date helper for picker decorations. Returns short
/// strings the picker can fit next to a weight × reps line:
///   • "today", "yesterday"
///   • "2d ago", "5d ago"
///   • "2w ago", "5w ago"
///   • "3mo ago"
///   • "6+ mo ago" (clamp for stale entries — old data isn't
///     actionable, so we don't waste space on exact months/years)
///
/// Reads off a passed `now` for testability. Caller-side the default
/// is `Date()`.
enum RelativeDate {
    static func short(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days < 0 { return "today" }            // Defensive — future-stamped data
        if days < 14 { return "\(days)d ago" }

        let weeks = days / 7
        if weeks < 8 { return "\(weeks)w ago" }

        let months = days / 30
        if months < 6 { return "\(months)mo ago" }
        return "6+ mo ago"
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

                // Top set is mode-aware: heaviest for reps, longest
                // hold for duration. Matches `WorkoutSession.topSet`.
                guard let top = session.topSet(for: exercise) else { continue }

                let totalVolume = completed.reduce(0.0) { $0 + $1.weight * Double($1.reps) }

                let point = ExerciseProgressPoint(
                    date: date,
                    topWeight: top.weight,
                    topReps: top.reps,
                    topDuration: top.duration,
                    trackingMode: exercise.trackingMode,
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
                // Sort by date ASC then walk to mark records at the
                // moment they were achieved — on the mode's primary
                // metric (top weight for reps, longest hold for time).
                let sorted = bucket.points.sorted { $0.date < $1.date }
                var runningMax: Double = -.infinity
                var flagged: [ExerciseProgressPoint] = []
                flagged.reserveCapacity(sorted.count)
                for var p in sorted {
                    let metric = p.trackingMode == .duration ? p.topDuration : p.topWeight
                    if metric > runningMax {
                        p.isWeightPR = true
                        runningMax = metric
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

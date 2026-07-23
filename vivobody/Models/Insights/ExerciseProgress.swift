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

private extension Exercise {
    /// Representative completed set for progress history. Comparable
    /// resistance uses effective load (so less machine assistance is
    /// better); non-comparable work retains a stable raw-marker choice
    /// for ordinary history without becoming PR-eligible.
    var progressTopSet: WorkoutSet? {
        representativeTopSet
    }
}

/// One data point in an exercise's progress series — the best set
/// completed in a given session, plus that session's total volume
/// for the exercise.
struct ExerciseProgressPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let topWeight: Double
    let topReps: Int

    /// Duration of the representative completed timed set. Loaded
    /// isometrics choose effective load first and duration second;
    /// duration-only work chooses the longest interval. Zero for reps.
    var topDuration: TimeInterval = 0

    /// How the exercise is measured — decides which metric
    /// (`topWeight` vs `topDuration`) the charts and stats read.
    var trackingMode: TrackingMode = .reps

    /// The exercise's training intent. Ordinary history remains
    /// chartable for every modality, while only supported strength
    /// modalities can create PRs or estimated-one-rep-max values.
    var modality: ExerciseModality = .dynamicStrength
    var loadMode: ExerciseLoadMode = .external
    var bodyweightFraction: Double = 0
    /// Historical body weight captured by the owning workout session.
    /// This keeps a pull-up performed at 180 lb distinct from one
    /// performed at 160 lb without consulting today's measurement.
    var bodyweightAtSession: Double = ExerciseLoad.unknownBodyweight

    var performanceSemanticKind: PerformanceSemanticKind {
        performanceSignature.performanceKind
    }

    var performanceSignature: ExercisePerformanceSignature {
        ExercisePerformanceSignature(
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
    }

    /// Known comparable-tonnage subtotal for this exercise in the
    /// session. `comparableTonnageAvailability` distinguishes a real
    /// zero from bodyweight-dependent work whose absolute load could
    /// not be recovered.
    let totalVolume: Double
    let comparableTonnageAvailability: ComparableTonnageAvailability

    /// Comparable resistance represented by this session's top set.
    /// Assisted work therefore improves when the entered assistance
    /// falls, while bodyweight work includes its carried-bodyweight
    /// share. Non-comparable work deliberately has no value here.
    var effectiveTopLoad: Double? {
        return ExerciseLoadProfile(
            mode: loadMode,
            bodyweightFraction: bodyweightFraction
        ).effectiveLoad(
            loggedWeight: topWeight,
            bodyweight: bodyweightAtSession
        )
    }

    /// Load used for an ordinary (non-PR) history line. Comparable
    /// work uses effective resistance; non-comparable movements retain
    /// their raw entered marker so their history does not disappear.
    /// Bodyweight-dependent comparable work with no captured bodyweight
    /// returns nil rather than relabeling added load or assistance as
    /// absolute resistance.
    var historyTopLoad: Double? {
        if let effectiveTopLoad { return effectiveTopLoad }
        return loadMode == .nonComparable ? max(0, topWeight) : nil
    }

    /// True when this point set a NEW best at the time it was logged.
    /// Dynamic work compares effective load then reps at equal load;
    /// loaded isometrics compare load then duration, and duration-only
    /// isometrics compare time. Computed chronologically so the flags
    /// match the live PR detector.
    var isStrengthPR: Bool = false

    /// Shared record-comparison value used by live, history, progress,
    /// plateau, and PR-wall reads.
    var strengthPerformance: StrengthPerformance? {
        StrengthPerformance.make(
            kind: performanceSemanticKind,
            effectiveLoad: effectiveTopLoad,
            reps: topReps,
            duration: topDuration
        )
    }

    /// Scalar y/display value for the record performance. Record
    /// ordering itself uses `strengthPerformance`, including reps as
    /// the tie-breaker for equal dynamic loads.
    var strengthPRMetric: Double? { strengthPerformance?.primaryMetric }

    /// Estimated 1-rep max via the Epley formula. Surfaced as one
    /// of the chartable metrics on the detail screen — useful when
    /// the user varies reps across sessions and the top-load
    /// curve oscillates more than the underlying strength trend.
    var estimated1RM: Double {
        guard modality.supportsEstimatedOneRepMax(
            for: trackingMode,
            loadMode: loadMode
        ), topReps > 0 else { return 0 }
        guard let effectiveLoad = effectiveTopLoad, effectiveLoad > 0 else { return 0 }
        return effectiveLoad * (1.0 + Double(topReps) / 30.0)
    }
}

/// Aggregated progress data for a single exercise across the user's
/// entire archive.
struct ExerciseProgress: Identifiable, Hashable {
    var id: String {
        ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: catalogItemID,
            name: name,
            performanceSignature: performanceSignature
        )
    }
    /// Stable bundled identity. Unlike the install-local catalog UUID,
    /// this survives Reset Exercise Catalog and reconnects old history
    /// to the freshly seeded item.
    var catalogID: String? = nil
    let catalogItemID: UUID?
    let name: String
    let group: MuscleGroup
    let points: [ExerciseProgressPoint]

    /// How this exercise is measured. Derived from its points (a
    /// single exercise has one consistent mode). Drives whether the
    /// progress UI reads weight or hold-time.
    var trackingMode: TrackingMode { points.last?.trackingMode ?? .reps }

    /// The most recently logged intent wins defensively if a custom
    /// exercise was reclassified between sessions.
    var modality: ExerciseModality { points.last?.modality ?? .dynamicStrength }

    var performanceSemanticKind: PerformanceSemanticKind {
        points.last?.performanceSemanticKind ?? .unrankedReps
    }

    var performanceSignature: ExercisePerformanceSignature {
        points.last?.performanceSignature ?? ExercisePerformanceSignature(
            modality: .conditioning,
            trackingMode: .reps,
            loadMode: .nonComparable,
            bodyweightFraction: 0
        )
    }

    /// The most recent point in the series. Used by the Me-tab row
    /// to surface "current top set" without the consumer having to
    /// know about sort order.
    var latest: ExerciseProgressPoint? { points.last }

    /// Point with the greatest history load. Comparable movements use
    /// effective resistance; non-comparable movements retain raw input
    /// solely as an ordinary history marker.
    var bestWeightPoint: ExerciseProgressPoint? {
        points
            .filter { $0.historyTopLoad != nil }
            .max { ($0.historyTopLoad ?? 0) < ($1.historyTopLoad ?? 0) }
    }

    /// The all-time greatest history load across logged sessions.
    /// This is effective resistance for bodyweight-added and
    /// assistance-subtracted movements.
    var bestWeight: Double {
        bestWeightPoint?.historyTopLoad ?? 0
    }

    /// Effective-load delta from the second-most-recent to the
    /// most-recent point. For non-comparable history, falls back to
    /// the raw entered marker without making it PR-eligible.
    var weightDelta: Double? {
        guard points.count >= 2 else { return nil }
        guard
            let latest = points[points.count - 1].historyTopLoad,
            let previous = points[points.count - 2].historyTopLoad
        else { return nil }
        return latest - previous
    }

    /// Hold-time delta between the two most-recent points — the
    /// `.duration` counterpart to `weightDelta`.
    var durationDelta: TimeInterval? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].topDuration - points[points.count - 2].topDuration
    }

    /// All-time best estimated 1-rep max across the series. The
    /// headline strength number on the detail screen — smoother than
    /// raw top load because it folds reps into the estimate, so a
    /// heavier-for-fewer set and a lighter-for-more set compare on one
    /// axis.
    var bestE1RM: Double {
        points.map(\.estimated1RM).max() ?? 0
    }

    /// The point that achieved `bestE1RM` — used to date the PR.
    var bestE1RMPoint: ExerciseProgressPoint? {
        points
            .filter { $0.estimated1RM > 0 }
            .max(by: { $0.estimated1RM < $1.estimated1RM })
    }

    /// Plateau check on the shared record performance (load then reps,
    /// loaded-isometric load then duration, or duration alone): counts
    /// how many of the most recent sessions have failed to set a new high,
    /// and reports a stall when that run reaches `threshold`. Points
    /// are chronological ascending, so the run is measured from the
    /// last PR to the latest session. Nil when there isn't a long
    /// enough stale streak (including brand-new exercises).
    func plateauStatus(threshold: Int) -> PlateauStatus? {
        guard performanceSemanticKind.supportsRecord else { return nil }
        let evaluable = points.compactMap(\.strengthPerformance)
        guard evaluable.count > threshold else { return nil }
        var runningBest: StrengthPerformance?
        var lastPRIndex = -1
        for (i, performance) in evaluable.enumerated() {
            guard performance.advancement(over: runningBest) != nil else { continue }
            runningBest = performance
            lastPRIndex = i
        }

        guard lastPRIndex >= 0, let runningBest else { return nil }
        let stale = (evaluable.count - 1) - lastPRIndex
        guard stale >= threshold else { return nil }
        return PlateauStatus(
            sessions: stale,
            performance: runningBest
        )
    }
}

/// A detected progression stall on an exercise's primary metric.
nonisolated struct PlateauStatus: Hashable {
    /// Consecutive sessions since the last all-time high.
    let sessions: Int
    /// The complete standing performance preserves the tie-breaker and
    /// prevents loaded holds from being flattened into an ambiguous time.
    let performance: StrengthPerformance

    var metric: Double { performance.primaryMetric }
    var metricKind: StrengthPerformanceMetricKind {
        performance.primaryMetricKind
    }
    /// Compatibility convenience for existing formatting call sites.
    var isDuration: Bool { metricKind == .duration }
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

    /// Meaning of `topWeight`, used so bodyweight-added and assisted
    /// entries never render as an unexplained raw zero or generic load.
    var loadMode: ExerciseLoadMode = .external

    /// Load-profile snapshot from the most recent session. Exercise
    /// details use this with `bodyweightAtSession` to explain the exact
    /// effective-load value that fed records and strength estimates.
    var bodyweightFraction: Double = 0

    /// Historical body weight captured when the most recent workout
    /// began. Zero remains the honest unknown sentinel.
    var bodyweightAtSession: Double = ExerciseLoad.unknownBodyweight

    /// Comparable resistance for the most recent top set, calculated
    /// with that session's bodyweight snapshot. The picker still shows
    /// the user's raw entry; detail strength summaries may use this.
    var effectiveTopLoad: Double? = nil

    /// Date the session was completed (or started, if completion
    /// timestamp is missing — defensive only, archived sessions
    /// always have completedAt set).
    let sessionDate: Date

    /// True when this top set matches the all-time best for the
    /// exercise on its mode's primary metric (effective load, or longest
    /// hold). Lets the picker show a subtle "PR" indicator.
    let isAllTimeBest: Bool

    /// Mode-aware one-line metric for picker / detail decorations,
    /// matching `Exercise.setLabel`: "145 × 8" for reps, "0:45"
    /// (or "25 × 0:45" when loaded) for a hold.
    func metricLabel(unit: WeightUnit) -> String {
        switch trackingMode {
        case .reps:
            let load = loadMode.loggedLoadLabel(
                topWeight,
                unit: unit,
                includeUnit: false
            )
            return load.map { "\($0) × \(topReps)" } ?? "\(topReps) reps"
        case .duration:
            let time = DurationFormatter.string(topDuration)
            guard let load = loadMode.loggedLoadLabel(
                    topWeight,
                    unit: unit,
                    includeUnit: false
                  ) else { return time }
            return "\(load) × \(time)"
        }
    }
}

extension Array where Element == WorkoutSession {
    /// Build a stable exercise-key → LastExerciseInstance lookup in one pass over
    /// the archive. Picker rows do O(1) lookups against this map
    /// instead of re-scanning history per row.
    ///
    /// Match is by the complete history key: stable ID for bundled
    /// movements and full performance signature for custom movements.
    func lastInstanceByExercise() -> [String: LastExerciseInstance] {
        // Step 1: gather every "top set per session per exercise"
        // tuple. The top set is modality/load-aware (greatest
        // effective resistance for comparable work, duration for
        // duration-only work) via `progressTopSet`. The arrays inside the
        // dictionary are appended in archive order, not by date —
        // sorting comes next.
        var rawByKey: [String: [(
            date: Date,
            top: WorkoutSet,
            mode: TrackingMode,
            modality: ExerciseModality,
            loadProfile: ExerciseLoadProfile,
            bodyweight: Double
        )]] = [:]

        for session in self {
            let date = session.completedAt ?? session.startedAt
            for exercise in session.orderedExercises {
                guard let top = exercise.progressTopSet else { continue }
                rawByKey[exercise.historyKey, default: []].append((
                    date: date,
                    top: top,
                    mode: exercise.trackingMode,
                    modality: exercise.modality,
                    loadProfile: exercise.loadProfile,
                    bodyweight: exercise.loadBodyweight
                ))
            }
        }

        // Step 2: for each exercise, find the most recent session's
        // top set AND the all-time best, compared on the mode's
        // primary metric. Two separate scans on a small list.
        var result: [String: LastExerciseInstance] = [:]
        for (key, entries) in rawByKey {
            guard let mostRecent = entries.max(by: { $0.date < $1.date }) else { continue }
            let mode = mostRecent.mode
            let currentKind = mostRecent.modality.performanceSemanticKind(
                for: mode,
                loadMode: mostRecent.loadProfile.mode
            )
            let currentEffectiveLoad = currentKind.comparesLoad
                ? mostRecent.loadProfile.effectiveLoad(
                    loggedWeight: mostRecent.top.weight,
                    bodyweight: mostRecent.bodyweight
                )
                : nil
            let currentPerformance = StrengthPerformance.make(
                kind: currentKind,
                effectiveLoad: currentEffectiveLoad,
                reps: mostRecent.top.reps,
                duration: mostRecent.top.duration
            )
            let allPerformances = entries.compactMap { entry -> StrengthPerformance? in
                let kind = entry.modality.performanceSemanticKind(
                    for: entry.mode,
                    loadMode: entry.loadProfile.mode
                )
                guard kind == currentKind else { return nil }
                let effectiveLoad = kind.comparesLoad
                    ? entry.loadProfile.effectiveLoad(
                        loggedWeight: entry.top.weight,
                        bodyweight: entry.bodyweight
                    )
                    : nil
                return StrengthPerformance.make(
                    kind: kind,
                    effectiveLoad: effectiveLoad,
                    reps: entry.top.reps,
                    duration: entry.top.duration
                )
            }
            let allTimeBest = allPerformances.reduce(nil as StrengthPerformance?) { best, candidate in
                guard let best else { return candidate }
                return candidate.beats(best) ? candidate : best
            }
            let isBest = currentPerformance != nil && currentPerformance == allTimeBest
            result[key] = LastExerciseInstance(
                topWeight: mostRecent.top.weight,
                topReps: mostRecent.top.reps,
                topDuration: mostRecent.top.duration,
                trackingMode: mode,
                loadMode: mostRecent.loadProfile.mode,
                bodyweightFraction: mostRecent.loadProfile.bodyweightFraction,
                bodyweightAtSession: mostRecent.bodyweight,
                effectiveTopLoad: currentEffectiveLoad,
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
    /// Group archived sessions by stable exercise history key and produce
    /// a chronological progress series for each. Only sessions with at
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
        var byKey: [String: (
            catalogID: String?,
            catalogItemID: UUID?,
            name: String,
            group: MuscleGroup,
            points: [ExerciseProgressPoint]
        )] = [:]

        for session in self {
            let date = session.completedAt ?? session.startedAt
            for exercise in session.orderedExercises {
                let completed = exercise.sets.filter(\.isAnalyticsEligible)
                guard !completed.isEmpty else { continue }

                // Top set is mode/load-aware: greatest effective
                // resistance for comparable work, duration for
                // duration-only work. Non-comparable work keeps an ordinary
                // history marker without becoming PR-eligible.
                guard let top = exercise.progressTopSet else { continue }

                let tonnage = exercise.comparableTonnageSummary

                let point = ExerciseProgressPoint(
                    date: date,
                    topWeight: top.weight,
                    topReps: top.reps,
                    topDuration: top.duration,
                    trackingMode: exercise.trackingMode,
                    modality: exercise.modality,
                    loadMode: exercise.loadMode,
                    bodyweightFraction: exercise.bodyweightFraction,
                    bodyweightAtSession: exercise.loadBodyweight,
                    totalVolume: tonnage.knownSubtotal,
                    comparableTonnageAvailability: tonnage.availability
                )

                let key = exercise.historyKey
                if var bucket = byKey[key] {
                    bucket.points.append(point)
                    byKey[key] = bucket
                } else {
                    byKey[key] = (
                        catalogID: exercise.catalogID,
                        catalogItemID: exercise.catalogItemID,
                        name: exercise.name,
                        group: exercise.group,
                        points: [point]
                    )
                }
            }
        }

        return byKey
            .filter { $0.value.points.count >= 2 }
            .map { _, bucket in
                // Sort by date ASC then walk to mark records at the
                // moment they were achieved — only when the exercise
                // modality supports a strength record for its mode.
                let sorted = bucket.points.sorted { $0.date < $1.date }
                var runningBest: StrengthPerformance?
                var flagged: [ExerciseProgressPoint] = []
                flagged.reserveCapacity(sorted.count)
                for var p in sorted {
                    if let performance = p.strengthPerformance,
                       performance.advancement(over: runningBest) != nil {
                        p.isStrengthPR = true
                        runningBest = performance
                    }
                    flagged.append(p)
                }
                return ExerciseProgress(
                    catalogID: bucket.catalogID,
                    catalogItemID: bucket.catalogItemID,
                    name: bucket.name,
                    group: bucket.group,
                    points: flagged
                )
            }
            .sorted { (lhs, rhs) in
                let lDate = lhs.latest?.date ?? .distantPast
                let rDate = rhs.latest?.date ?? .distantPast
                return lDate > rDate
            }
    }
}

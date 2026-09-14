//
//  ArchiveOverview.swift
//  vivobody
//
//  Archive-level scalars computed once per analytics generation and
//  cached in SessionAnalytics.CoreReports, so no screen has to hold a
//  full-history query (or fault every exercise and set) just to show
//  lifetime totals, calendar-ready consistency history, PR-session and
//  PR-exercise badges, or the forge's warmth. Pure snapshot math — runs
//  on the background worker.
//

import Foundation

/// Calendar-ready archive membership built once with the analytics generation.
/// Month grids perform constant-time day lookups and never normalize or count
/// the lifetime archive while SwiftUI evaluates their bodies.
nonisolated struct ConsistencyHistory {
    let workoutDays: Set<Date>
    let monthStartsNewestFirst: [Date]
    let workoutDayCountByMonth: [Date: Int]

    static func make(
        dates: [Date],
        now: Date,
        calendar: Calendar
    ) -> ConsistencyHistory {
        let workoutDays = Set(dates.map { calendar.startOfDay(for: $0) })
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let firstMonth = workoutDays.min()
            .flatMap { calendar.dateInterval(of: .month, for: $0)?.start }
            ?? thisMonth
        let span = max(
            calendar.dateComponents(
                [.month],
                from: firstMonth,
                to: thisMonth
            ).month ?? 0,
            0
        )
        let monthStarts = (0 ... span).compactMap {
            calendar.date(byAdding: .month, value: -$0, to: thisMonth)
        }
        var counts: [Date: Int] = [:]
        for day in workoutDays {
            guard let month = calendar.dateInterval(of: .month, for: day)?.start else {
                continue
            }
            counts[month, default: 0] += 1
        }
        return ConsistencyHistory(
            workoutDays: workoutDays,
            monthStartsNewestFirst: monthStarts,
            workoutDayCountByMonth: counts
        )
    }
}

/// The archive reduced to the handful of values the shell and tabs
/// actually read: journey totals for Me, the streak, the month recap,
/// the set of sessions that contained a strength PR at the moment it
/// was logged, and the ambient forge temperature.
nonisolated struct ArchiveOverview {
    /// Lifetime archived-workout count.
    let totalWorkouts: Int
    /// Lifetime completed-set count (matches `WorkoutSession.totalSets`).
    let totalSets: Int
    /// Lifetime comparable tonnage with completeness.
    let lifetimeTonnage: ComparableTonnageSummary
    /// Earliest completion — the first day of logged training.
    let trainingSince: Date?
    /// Lifetime workout cadence, averaged from the first logged day
    /// through `now` with a one-week minimum observation span.
    let averageWorkoutsPerWeek: Double
    /// Weeks-in-a-row consistency (current + longest).
    let streak: WorkoutStreak
    /// Normalized day membership and month metadata for the full
    /// Consistency screen.
    let consistencyHistory: ConsistencyHistory
    /// The current calendar month's recap.
    let monthlyRecap: MonthlyRecap
    /// IDs of sessions in which at least one exercise hit a new
    /// all-time strength record at the moment it was logged — the same
    /// walk History and Today used to run per render.
    let prSessionIDs: Set<UUID>
    /// Exercise-instance IDs that set a strength record, grouped by their
    /// session so Session Detail can resolve one small set in constant time.
    let prExerciseIDsBySession: [UUID: Set<UUID>]
    /// 0–1 ambient forge temperature (streak + recency, floored).
    let forgeWarmth: Double
}

// MARK: - Forge warmth

/// Warmth (0–1) for the ambient forge: hottest right after training
/// and while a streak is alive, cooling toward a low idle glow as days
/// pass. Floored well above zero — the instrument is always on. The
/// single source of truth so every tab burns at one temperature.
nonisolated enum ForgeWarmth {
    /// The idle floor the forge never cools below.
    static let idle = 0.34

    static func compute(
        dates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let streakBoost = Swift.min(1.0, Double(streakDays(dates, now: now, calendar: calendar)) / 7.0)
        let days = daysSinceLast(dates, now: now, calendar: calendar)
        let recency: Double = if let days {
            Swift.max(0.0, 1.0 - Double(days) / 5.0)
        } else {
            0.0
        }
        let trainedTodayBoost = days == 0 ? 0.15 : 0.0
        return Swift.min(1.0, Swift.max(idle, 0.5 * recency + 0.5 * streakBoost + trainedTodayBoost))
    }

    /// Consecutive training days counting back from today — forgiving
    /// of an unworked morning by starting from yesterday when needed.
    private static func streakDays(
        _ dates: [Date],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    /// Whole days since the most recent session, or nil when empty.
    private static func daysSinceLast(
        _ dates: [Date],
        now: Date,
        calendar: Calendar
    ) -> Int? {
        guard let latest = dates.max() else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latest),
            to: calendar.startOfDay(for: now)
        ).day
    }
}

// MARK: - Computation

nonisolated extension AnalyticsAccumulator {
    /// Reduce the replayed archive to its overview in one pass.
    /// `progress` is the already-built per-exercise series (the same
    /// generation), reused for the month's PR count.
    func archiveOverview(
        progress: [ExerciseProgress],
        now: Date = Date(),
        calendar: Calendar = .current,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> ArchiveOverview {
        // The PR walk needs strict chronological order. The shared
        // replay already sorts, but `.history` accumulators preserve
        // caller order — sort defensively so semantics never depend on
        // which path built the accumulator.
        let completed = sessions
            .filter(\.isCompleted)
            .sorted { $0.date < $1.date }

        let monthInterval = calendar.dateInterval(of: .month, for: now)

        var totalSets = 0
        var lifetimeTonnage = ComparableTonnageSummary.zero
        var trainingSince: Date?
        var dates: [Date] = []
        dates.reserveCapacity(completed.count)
        var monthWorkouts = 0
        var monthSets = 0
        var monthTonnage = ComparableTonnageSummary.zero
        var bestByExercise: [String: StrengthPerformance] = [:]
        var prSessionIDs: Set<UUID> = []
        var prExerciseIDsBySession: [UUID: Set<UUID>] = [:]

        for replay in completed {
            guard !isCancelled() else { break }
            let session = replay.session
            let sets = session.totalCompletedSets
            let sessionTonnage = Self.accumulateExercises(
                replay,
                bestByExercise: &bestByExercise,
                prSessionIDs: &prSessionIDs,
                prExerciseIDsBySession: &prExerciseIDsBySession,
                isCancelled: isCancelled
            )

            totalSets += sets
            dates.append(session.date)
            trainingSince = Self.earliest(trainingSince, session.completedAt)

            lifetimeTonnage = lifetimeTonnage.merging(sessionTonnage)
            if let done = session.completedAt, let monthInterval,
               done >= monthInterval.start, done < monthInterval.end
            {
                monthWorkouts += 1
                monthSets += sets
                monthTonnage = monthTonnage.merging(sessionTonnage)
            }
        }

        let monthPRs: Int = if let monthInterval {
            progress.reduce(0) { acc, prog in
                acc + prog.points.count(where: {
                    $0.isStrengthPR
                        && $0.date >= monthInterval.start
                        && $0.date < monthInterval.end
                })
            }
        } else {
            0
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"

        // A first workout should read as 1.0/week, not an extrapolated
        // 7.0/week. After the first seven days the denominator expands
        // continuously through `now`, so this remains a true lifetime
        // rate and naturally reflects inactive stretches.
        let cadenceDates = dates.filter { $0 <= now }
        let averageWorkoutsPerWeek = Self.averageWorkoutsPerWeek(
            dates: cadenceDates,
            now: now,
            calendar: calendar
        )

        let consistencyHistory = ConsistencyHistory.make(
            dates: dates,
            now: now,
            calendar: calendar
        )

        return ArchiveOverview(
            totalWorkouts: completed.count,
            totalSets: totalSets,
            lifetimeTonnage: lifetimeTonnage,
            trainingSince: trainingSince,
            averageWorkoutsPerWeek: averageWorkoutsPerWeek,
            streak: WorkoutStreak.compute(dates: dates, now: now, calendar: calendar),
            consistencyHistory: consistencyHistory,
            monthlyRecap: MonthlyRecap(
                monthLabel: monthFormatter.string(from: now),
                workouts: monthWorkouts,
                volume: monthTonnage.knownSubtotal,
                volumeAvailability: monthTonnage.availability,
                sets: monthSets,
                prs: monthPRs
            ),
            prSessionIDs: prSessionIDs,
            prExerciseIDsBySession: prExerciseIDsBySession,
            forgeWarmth: ForgeWarmth.compute(dates: dates, now: now, calendar: calendar)
        )
    }

    private static func earliest(_ current: Date?, _ candidate: Date?) -> Date? {
        guard let candidate else { return current }
        return current.map { min($0, candidate) } ?? candidate
    }

    private static func accumulateExercises(
        _ replay: AnalyticsSessionReplay,
        bestByExercise: inout [String: StrengthPerformance],
        prSessionIDs: inout Set<UUID>,
        prExerciseIDsBySession: inout [UUID: Set<UUID>],
        isCancelled: @Sendable () -> Bool
    ) -> ComparableTonnageSummary {
        var tonnage = ComparableTonnageSummary.zero
        for exerciseReplay in replay.exercises {
            guard !isCancelled() else { break }
            let exercise = exerciseReplay.exercise
            tonnage = tonnage.merging(exercise.comparableTonnageSummary)
            guard let performance = exercise.bestStrengthPerformance else { continue }
            let key = exercise.historyKey
            guard bestByExercise[key].map({ performance.beats($0) }) ?? true else { continue }
            bestByExercise[key] = performance
            prSessionIDs.insert(replay.session.id)
            prExerciseIDsBySession[replay.session.id, default: []].insert(exercise.id)
        }
        return tonnage
    }

    private static func averageWorkoutsPerWeek(
        dates: [Date],
        now: Date,
        calendar: Calendar
    ) -> Double {
        guard let first = dates.min() else { return 0 }
        let daySpan = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: first),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return Double(dates.count) * 7.0 / Double(max(7, daySpan + 1))
    }
}

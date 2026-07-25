//
//  ArchiveOverview.swift
//  vivobody
//
//  Archive-level scalars computed once per analytics generation and
//  cached in SessionAnalytics.CoreReports, so no screen has to hold a
//  full-history query (or fault every exercise and set) just to show
//  lifetime totals, the week streak, PR-session badges, or the forge's
//  warmth. Pure snapshot math — runs on the background worker.
//

import Foundation

/// The archive reduced to the handful of values the shell and tabs
/// actually read: journey totals for Me, the streak, the month recap,
/// the set of sessions that contained a strength PR at the moment it
/// was logged, and the ambient forge temperature.
nonisolated struct ArchiveOverview: Sendable {
    /// Lifetime archived-workout count.
    let totalWorkouts: Int
    /// Lifetime completed-set count (matches `WorkoutSession.totalSets`).
    let totalSets: Int
    /// Lifetime comparable tonnage with completeness.
    let lifetimeTonnage: ComparableTonnageSummary
    /// Earliest completion — the first day of logged training.
    let trainingSince: Date?
    /// Weeks-in-a-row consistency (current + longest).
    let streak: WorkoutStreak
    /// The current calendar month's recap.
    let monthlyRecap: MonthlyRecap
    /// IDs of sessions in which at least one exercise hit a new
    /// all-time strength record at the moment it was logged — the same
    /// walk History and Today used to run per render.
    let prSessionIDs: Set<UUID>
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
        let recency: Double
        if let days {
            recency = Swift.max(0.0, 1.0 - Double(days) / 5.0)
        } else {
            recency = 0.0
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

        sessionLoop: for replay in completed {
            guard !isCancelled() else { break }
            let session = replay.session
            let sets = session.totalCompletedSets
            var sessionTonnage = ComparableTonnageSummary.zero

            totalSets += sets
            dates.append(session.date)
            if let done = session.completedAt {
                if trainingSince == nil || done < trainingSince! {
                    trainingSince = done
                }
            }

            for exerciseReplay in replay.exercises {
                guard !isCancelled() else { break sessionLoop }
                let exercise = exerciseReplay.exercise
                sessionTonnage = sessionTonnage.merging(
                    exercise.comparableTonnageSummary
                )
                if let performance = exercise.bestStrengthPerformance {
                    let key = exercise.historyKey
                    if bestByExercise[key] == nil || performance.beats(bestByExercise[key]!) {
                        bestByExercise[key] = performance
                        prSessionIDs.insert(session.id)
                    }
                }
            }

            lifetimeTonnage = lifetimeTonnage.merging(sessionTonnage)
            if let done = session.completedAt, let monthInterval,
               done >= monthInterval.start, done < monthInterval.end {
                monthWorkouts += 1
                monthSets += sets
                monthTonnage = monthTonnage.merging(sessionTonnage)
            }
        }

        let monthPRs: Int
        if let monthInterval {
            monthPRs = progress.reduce(0) { acc, prog in
                acc + prog.points.filter {
                    $0.isStrengthPR
                        && $0.date >= monthInterval.start
                        && $0.date < monthInterval.end
                }.count
            }
        } else {
            monthPRs = 0
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"

        return ArchiveOverview(
            totalWorkouts: completed.count,
            totalSets: totalSets,
            lifetimeTonnage: lifetimeTonnage,
            trainingSince: trainingSince,
            streak: WorkoutStreak.compute(dates: dates, now: now, calendar: calendar),
            monthlyRecap: MonthlyRecap(
                monthLabel: monthFormatter.string(from: now),
                workouts: monthWorkouts,
                volume: monthTonnage.knownSubtotal,
                volumeAvailability: monthTonnage.availability,
                sets: monthSets,
                prs: monthPRs
            ),
            prSessionIDs: prSessionIDs,
            forgeWarmth: ForgeWarmth.compute(dates: dates, now: now, calendar: calendar)
        )
    }
}

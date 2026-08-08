//
//  MuscleVolume.swift
//  vivobody
//
//  Weekly HARD SETS per muscle — the evidence-based volume landmark
//  serious lifters track by hand (≈ 10–20 hard sets per muscle per
//  week). It answers the two questions the coarse chest/back/legs
//  rollup can't: which muscles are getting enough work, and which are
//  quietly being neglected.
//
//  Two ideas make the count honest. First, the role-based involvement
//  map (`Muscle.involvement`): primary muscles receive one set,
//  secondary muscles receive half a set, and stabilizers receive no
//  hypertrophy-volume credit. Stabilizers remain available to the body
//  visualization without inflating training volume. Second, the shared
//  `SetStimulus` currency: each completed set counts 1.0, discounted
//  only when the user's own logged RIR says it was stopped far from
//  failure. `MuscleDevelopment` (the 3D body) consumes the identical
//  pricing, so the bars, the neglect list, and the body can never
//  drift onto different definitions of "a set of work."
//
//  Only COMPLETED sets count. Everything is a PURE value-type
//  computation driven by injected dates, so it's fully testable
//  without a simulator (see `MuscleVolumeTests`).
//

import Foundation

// MARK: - Volume landmark

/// The productive weekly set range, in hard sets. Below `mev`
/// (minimum effective volume) a muscle is under-stimulated; inside
/// the band it's progressing; above `optimalHigh` the extra work
/// trades into recovery debt / junk volume.
///
/// ONE band for every muscle, on purpose. The counts it judges are
/// estimates built from authored catalog roles — a per-muscle
/// landmark table implied physiological precision the input data
/// cannot back (and made spillover-fed regions outrank directly
/// trained ones). Directional guidance, not gospel; values are a
/// touch higher than textbook "direct set" landmarks because the
/// count folds in synergist credit. Kept in one place so they can be
/// calibrated without touching the UI.
nonisolated struct VolumeLandmark: Hashable, Sendable {
    var mev: Double
    var optimalHigh: Double

    static let `default` = VolumeLandmark(mev: 8, optimalHigh: 18)
}

// MARK: - Zone

/// Where a muscle's weekly effective-set count lands relative to its
/// landmark band. Drives both the colour of its bar and the summary
/// counts.
nonisolated enum VolumeZone: Hashable, Sendable {
    /// No completed work in the window at all — fully rested / neglected.
    case untrained
    /// Worked, but below the minimum effective volume.
    case under
    /// Inside the productive band.
    case optimal
    /// Above the band — recovery / junk-volume territory.
    case high
}

// MARK: - Per-muscle stat

/// One muscle's volume picture: how many effective sets it received
/// in the caller's window, its all-time allocation for the Training
/// Signature, when it was last trained (over the whole archive, not
/// just the current window), and the weekly landmark it's judged
/// against.
nonisolated struct MuscleVolumeStat: Identifiable, Hashable, Sendable {
    var id: Muscle { muscle }
    let muscle: Muscle
    /// Effective sets in the caller-selected window (normally 7 days).
    let effectiveSets: Double
    /// Effective sets across the complete archive. Kept separate from
    /// `effectiveSets` so weekly volume surfaces and the lifetime
    /// Training Signature never silently share different timeframes.
    let allTimeEffectiveSets: Double
    /// Whole days since the muscle last received any completed work.
    /// `nil` means it's never been trained.
    let daysSinceLastTrained: Int?
    let landmark: VolumeLandmark

    var zone: VolumeZone {
        if effectiveSets <= 0 { return .untrained }
        if effectiveSets < landmark.mev { return .under }
        if effectiveSets <= landmark.optimalHigh { return .optimal }
        return .high
    }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
    /// Hard sets per muscle over a rolling `window` ending at `now`
    /// (default: the last 7 days). Every trainable muscle is
    /// returned — including ones with zero work, so neglect is
    /// visible rather than missing. Recency (`daysSinceLastTrained`)
    /// and the all-time totals scan the full archive, so a muscle
    /// untouched this week still reports how long it's been.
    func muscleVolume(
        window: TimeInterval = 7 * 86_400,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [MuscleVolumeStat] {
        AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: self),
            isCancelled: isCancelled
        ).muscleVolume(
            window: window,
            now: now,
            isCancelled: isCancelled
        )
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Build weekly volume from the shared hard-set replay. This path is
    /// used by SessionAnalytics so development, load, and map reports do
    /// not each reprice the archive.
    func muscleVolume(
        window: TimeInterval = 7 * 86_400,
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [MuscleVolumeStat] {
        let cutoff = now.addingTimeInterval(-window)
        var effective: [Muscle: Double] = [:]
        var allTimeEffective: [Muscle: Double] = [:]
        var lastTrained: [Muscle: Date] = [:]

        sessionReplay: for session in sessions {
            guard !isCancelled() else { return [] }
            // Reports are snapshots "as of" `now`; scheduled or
            // accidentally future-dated sessions cannot count as work
            // already performed or produce negative recency.
            guard session.date <= now else { continue }
            for exercise in session.exercises {
                guard !isCancelled() else { break sessionReplay }
                let credit = exercise.byMuscle
                guard !credit.isEmpty else { continue }

                let inWindow = session.date >= cutoff
                for (muscle, sets) in credit {
                    guard !isCancelled() else { return [] }
                    // Recency tracks the whole archive.
                    if let existing = lastTrained[muscle] {
                        if session.date > existing { lastTrained[muscle] = session.date }
                    } else {
                        lastTrained[muscle] = session.date
                    }
                    // Effective sets only accrue inside the window.
                    if inWindow {
                        effective[muscle, default: 0] += sets
                    }
                    allTimeEffective[muscle, default: 0] += sets
                }
            }
        }

        let calendar = Calendar.current
        var result: [MuscleVolumeStat] = []
        result.reserveCapacity(Muscle.allCases.count)
        for muscle in Muscle.allCases {
            guard !isCancelled() else { return [] }
            let days: Int?
            if let last = lastTrained[muscle] {
                days = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: last),
                    to: calendar.startOfDay(for: now)
                ).day
            } else {
                days = nil
            }
            result.append(MuscleVolumeStat(
                muscle: muscle,
                effectiveSets: effective[muscle] ?? 0,
                allTimeEffectiveSets: allTimeEffective[muscle] ?? 0,
                daysSinceLastTrained: days,
                landmark: .default
            ))
        }
        return result
    }
}

// MARK: - Summary rollups

/// Screen-level summary derived from a set of `MuscleVolumeStat`s:
/// the zone tallies for the glance strip and the ranked neglect list
/// for the headline insight.
nonisolated struct MuscleVolumeSummary: Sendable {
    let optimalCount: Int
    let underCount: Int
    let restingCount: Int
    let highCount: Int

    /// Muscles needing attention, most-neglected first: never-trained
    /// and longest-rested ahead of merely-under ones. Used to name
    /// names in the headline.
    let neglected: [MuscleVolumeStat]

    /// Was anything trained at all in the window?
    var hasWindowActivity: Bool {
        optimalCount + underCount + highCount > 0
    }
}

nonisolated extension Array where Element == MuscleVolumeStat {
    var summary: MuscleVolumeSummary {
        let optimal = filter { $0.zone == .optimal }.count
        let under = filter { $0.zone == .under }.count
        let high = filter { $0.zone == .high }.count
        let resting = filter { $0.zone == .untrained }.count

        // Severity order: rested muscles first (by staleness, never
        // trained last on the date axis but most neglected), then
        // under-volume muscles by how far short they fall.
        let neglected = filter { $0.zone == .untrained || $0.zone == .under }
            .sorted { lhs, rhs in
                switch (lhs.zone, rhs.zone) {
                case (.untrained, .under): return true
                case (.under, .untrained): return false
                case (.untrained, .untrained):
                    // Longer rest = more neglected; never-trained
                    // (nil) sorts as most neglected of all.
                    return (lhs.daysSinceLastTrained ?? .max) > (rhs.daysSinceLastTrained ?? .max)
                default:
                    // Both under: fewer effective sets = more neglected.
                    return lhs.effectiveSets < rhs.effectiveSets
                }
            }

        return MuscleVolumeSummary(
            optimalCount: optimal,
            underCount: under,
            restingCount: resting,
            highCount: high,
            neglected: neglected
        )
    }
}

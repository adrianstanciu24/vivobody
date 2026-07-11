//
//  MuscleVolume.swift
//  vivobody
//
//  Weekly HARD-SET EQUIVALENTS per muscle — the evidence-based volume
//  landmark serious lifters track by hand (≈ 10–20 hard sets per
//  muscle per week). It answers the two questions the coarse
//  chest/back/legs rollup can't: which muscles are getting enough
//  work, and which are quietly being neglected.
//
//  Two ideas make the count honest. First, the GRADED involvement
//  map (`Muscle.involvement`): a set isn't credited whole to one
//  bucket — it's split across every muscle it actually works, by that
//  muscle's contribution weight. One Bench Press set therefore counts
//  as 1.0 set for chest, 0.7 for triceps, and 0.4 for the front
//  delts. Second, the shared `SetStimulus` currency: each completed
//  set is priced as a hard-set equivalent — full credit for a real
//  working set, demoted for warm-up loads, token weights, heavy
//  singles, and sets stopped far from failure (RIR). A logged plank
//  hold prices on its length the same way. `MuscleDevelopment` (the
//  3D body) consumes the identical calculator, so the bars, the
//  neglect list, and the body can never drift onto different
//  definitions of "a set of work."
//
//  Only COMPLETED sets count. Everything is a PURE value-type
//  computation driven by injected dates, so it's fully testable
//  without a simulator (see `MuscleVolumeTests`).
//

import Foundation

// MARK: - Volume landmark

/// The productive weekly set range for a muscle, in effective sets.
/// Below `mev` (minimum effective volume) a muscle is under-stimulated;
/// inside the band it's progressing; above `optimalHigh` the extra
/// work trades into recovery debt / junk volume.
///
/// Values are deliberately a touch higher than textbook "direct set"
/// landmarks because our effective-set count folds in synergist
/// credit (a muscle accrues fractional sets from compounds it only
/// assists on). They're directional guidance, not gospel — kept in
/// one place so they can be calibrated without touching the UI.
nonisolated struct VolumeLandmark: Hashable {
    var mev: Double
    var optimalHigh: Double

    static let `default` = VolumeLandmark(mev: 8, optimalHigh: 18)

    /// Per-muscle range. Small / high-traffic muscles tolerate more
    /// volume; fatigue-prone stabilisers and indirectly-worked
    /// regions plateau earlier.
    static func landmark(for muscle: Muscle) -> VolumeLandmark {
        switch muscle {
        case .deltoids, .calves, .abs, .obliques, .biceps, .triceps, .forearms:
            return VolumeLandmark(mev: 8, optimalHigh: 22)
        case .lowerBack, .hipFlexors, .shins, .serratus,
             .teres, .rhomboids, .adductors:
            return VolumeLandmark(mev: 5, optimalHigh: 14)
        case .pectorals, .lats, .traps, .quads, .hamstrings, .glutes:
            return VolumeLandmark(mev: 8, optimalHigh: 20)
        }
    }
}

// MARK: - Zone

/// Where a muscle's weekly effective-set count lands relative to its
/// landmark band. Drives both the colour of its bar and the summary
/// counts.
nonisolated enum VolumeZone: Hashable {
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

/// One muscle's weekly volume picture: how many effective sets it
/// received in the window, when it was last trained (over the whole
/// archive, not just the window), and the landmark it's judged
/// against.
nonisolated struct MuscleVolumeStat: Identifiable, Hashable {
    var id: Muscle { muscle }
    let muscle: Muscle
    let effectiveSets: Double
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

extension Array where Element == WorkoutSession {
    /// Hard-set equivalents per muscle over a rolling `window` ending
    /// at `now` (default: the last 7 days). Every trainable muscle is
    /// returned — including ones with zero work, so neglect is
    /// visible rather than missing. Recency (`daysSinceLastTrained`)
    /// scans the full archive so a muscle untouched this week still
    /// reports how long it's been. The whole archive is replayed
    /// chronologically (not just the window) so the `SetStimulus`
    /// load references are causal.
    func muscleVolume(
        window: TimeInterval = 7 * 86_400,
        now: Date = Date()
    ) -> [MuscleVolumeStat] {
        let cutoff = now.addingTimeInterval(-window)

        var effective: [Muscle: Double] = [:]
        var lastTrained: [Muscle: Date] = [:]
        var calculator = SetStimulus.Calculator()

        let ordered = sorted {
            ($0.completedAt ?? $0.startedAt) < ($1.completedAt ?? $1.startedAt)
        }

        for session in ordered {
            let date = session.completedAt ?? session.startedAt
            for exercise in session.orderedExercises {
                let credit = calculator.credit(for: exercise, at: date)
                guard !credit.isEmpty else { continue }

                let inWindow = date >= cutoff
                for (muscle, sets) in credit {
                    // Recency tracks the whole archive.
                    if let existing = lastTrained[muscle] {
                        if date > existing { lastTrained[muscle] = date }
                    } else {
                        lastTrained[muscle] = date
                    }
                    // Effective sets only accrue inside the window.
                    if inWindow {
                        effective[muscle, default: 0] += sets
                    }
                }
            }
        }

        let calendar = Calendar.current
        return Muscle.allCases.map { muscle in
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
            return MuscleVolumeStat(
                muscle: muscle,
                effectiveSets: effective[muscle] ?? 0,
                daysSinceLastTrained: days,
                landmark: VolumeLandmark.landmark(for: muscle)
            )
        }
    }
}

// MARK: - Summary rollups

/// Screen-level summary derived from a set of `MuscleVolumeStat`s:
/// the zone tallies for the glance strip and the ranked neglect list
/// for the headline insight.
nonisolated struct MuscleVolumeSummary {
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

extension Array where Element == MuscleVolumeStat {
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

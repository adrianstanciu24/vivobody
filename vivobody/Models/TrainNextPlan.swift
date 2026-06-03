//
//  TrainNextPlan.swift
//  vivobody
//
//  The triage model behind the Insights "Train next" section. The old
//  tab answered the same question in three separate per-muscle bar
//  walls — Muscle Balance (under-trained), Momentum (fading), and
//  Forecast (about to detrain). This fuses all three into ONE ranked
//  priority list: for every muscle it keeps only the single most
//  urgent reason to train it, scores that reason, and sorts so the
//  few things actually worth acting on float to the top.
//
//  Priority bands (so the ordering is legible, not magic):
//    • at-risk  (90→76) — development will start slipping within the
//      week if untrained. The most time-sensitive signal.
//    • fading   (55→75) — already trending down.
//    • under    (30→55) — below its productive weekly volume.
//    • resting  (8→30)  — no work in the window; ranked by staleness.
//
//  Pure value type built from the other models' outputs (mirrors
//  `TrainingSignature`), so no extra simulation and it stays testable.
//

import Foundation

// MARK: - Reason

/// Why a muscle earned a spot on the list — carries the numbers each
/// row needs to render its own signal and copy.
nonisolated enum TrainNextReason: Hashable {
    /// Forecast says development dips within `daysUntilFade` days.
    case atRisk(daysUntilFade: Int)
    /// Momentum is negative — `momentum` in `-1...0`.
    case fading(momentum: Double)
    /// Below the muscle's minimum effective volume this week.
    case underVolume(current: Double, target: Double)
    /// No work in the window. `daysSince` is `nil` if never trained.
    case resting(daysSince: Int?)
}

// MARK: - Item

nonisolated struct TrainNextItem: Identifiable, Hashable {
    var id: Muscle { muscle }
    let muscle: Muscle
    let reason: TrainNextReason
    /// Higher = more worth acting on. See the priority bands above.
    let priority: Double
}

// MARK: - Plan

nonisolated struct TrainNextPlan {
    /// Every flagged muscle, most-urgent first.
    let items: [TrainNextItem]
    /// Muscles inside their productive volume band — the affirmation.
    let optimalCount: Int
    /// Muscles that received any work in the window.
    let trainedCount: Int

    /// Below this, an item is "resting / barely under" rather than
    /// something pressing enough to frame as urgent.
    static let pressingFloor = 40.0
    /// Forecast fade horizon that still reads as "train this week."
    static let atRiskWindowDays = 7

    var hasItems: Bool { !items.isEmpty }

    /// Items urgent enough to headline (at-risk / fading / notably
    /// under), as opposed to merely resting.
    var pressing: [TrainNextItem] {
        items.filter { $0.priority >= Self.pressingFloor }
    }

    func top(_ n: Int) -> [TrainNextItem] { Array(items.prefix(n)) }

    init(
        volume: [MuscleVolumeStat],
        momentum: MuscleMomentumBoard,
        forecast: MuscleForecastBoard
    ) {
        var byMuscle: [Muscle: TrainNextItem] = [:]

        // Keep only the highest-scoring reason per muscle.
        func consider(_ muscle: Muscle, _ reason: TrainNextReason, _ priority: Double) {
            if let existing = byMuscle[muscle], existing.priority >= priority { return }
            byMuscle[muscle] = TrainNextItem(muscle: muscle, reason: reason, priority: priority)
        }

        // At-risk: about to lose development if left untrained.
        for stat in forecast.ranked where stat.daysUntilFade <= Self.atRiskWindowDays {
            let p = 90 - Double(stat.daysUntilFade) * 2
            consider(stat.muscle, .atRisk(daysUntilFade: stat.daysUntilFade), p)
        }

        // Fading: development trending down.
        for stat in momentum.fading {
            let p = 55 + Swift.min(20, abs(stat.momentum) * 20)
            consider(stat.muscle, .fading(momentum: stat.momentum), p)
        }

        // Volume shortfalls and rest.
        for stat in volume {
            switch stat.zone {
            case .under:
                let mev = stat.landmark.mev
                let deficitFrac = mev > 0 ? Swift.min(1, Swift.max(0, (mev - stat.effectiveSets) / mev)) : 0
                consider(stat.muscle, .underVolume(current: stat.effectiveSets, target: mev), 30 + 25 * deficitFrac)
            case .untrained:
                if let days = stat.daysSinceLastTrained {
                    consider(stat.muscle, .resting(daysSince: days), 15 + Swift.min(15, Double(days) / 3))
                } else {
                    consider(stat.muscle, .resting(daysSince: nil), 8)
                }
            case .optimal, .high:
                break
            }
        }

        // Stable order: priority desc, then anatomical order so ties
        // don't shuffle between renders.
        let order = Dictionary(
            uniqueKeysWithValues: Muscle.allCases.enumerated().map { ($1, $0) }
        )
        items = byMuscle.values.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return (order[lhs.muscle] ?? 0) < (order[rhs.muscle] ?? 0)
        }

        optimalCount = volume.filter { $0.zone == .optimal }.count
        trainedCount = volume.filter { $0.zone != .untrained }.count
    }
}

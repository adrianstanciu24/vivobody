//
//  MuscleMomentum.swift
//  vivobody
//
//  The growth-trend companion to MuscleVolume. Where the balance view
//  asks "is each muscle getting enough work?", this asks "is each
//  muscle actually GROWING, holding, or slipping?" — the trajectory,
//  not the dose.
//
//  It's a thin projection of the `MuscleDevelopment` dynamical model,
//  which already computes a per-muscle MOMENTUM channel (fast-minus-
//  slow adaptation: positive while progressing, ~0 on a plateau,
//  negative during a layoff). Today that signal only tints the 3D
//  body; here it's surfaced as a legible board.
//
//  Muscles below a small development floor are dropped — a barely-
//  touched or fully-faded muscle has no meaningful trend, and the
//  balance view's "resting / never trained" already speaks for it.
//
//  Pure value type driven by injected dates, so it's testable on a
//  virtual clock with no simulator (see `MuscleMomentumTests`).
//

import Foundation

// MARK: - Trend

/// Which way a developed muscle is heading.
nonisolated enum MomentumTrend: Hashable {
    case growing
    case holding
    case fading
}

// MARK: - Per-muscle stat

nonisolated struct MuscleMomentumStat: Identifiable, Hashable {
    var id: Muscle { muscle }
    let muscle: Muscle
    let trend: MomentumTrend
    /// Normalised growth momentum, `-1...1`.
    let momentum: Double
    /// Development level, `0...1` — how far the muscle has come, used
    /// to give the trend context (highly-developed-and-growing reads
    /// differently from barely-there-but-growing).
    let adaptation: Double
    /// Whole days since the muscle last received work. `nil` only in
    /// defensive cases; trained muscles always carry a stamp.
    let daysSinceLastTrained: Int?
}

// MARK: - Board

/// The three trend buckets, each sorted for display, plus the tallies
/// and the "losing ground" list the headline names.
nonisolated struct MuscleMomentumBoard {
    /// Momentum above this reads as growing; below its negative as
    /// fading; in between, holding. Tunable here without touching UI.
    static let growingThreshold = 0.15
    static let fadingThreshold = -0.15
    /// Muscles less developed than this are excluded — no real trend
    /// to speak of yet.
    static let developmentFloor = 0.03

    let growing: [MuscleMomentumStat]
    let holding: [MuscleMomentumStat]
    let fading: [MuscleMomentumStat]

    init(stats: [MuscleMomentumStat]) {
        // Most-growing first; most-developed first among the steady;
        // most-negative (most-slipping) first among the fading.
        growing = stats.filter { $0.trend == .growing }.sorted { $0.momentum > $1.momentum }
        holding = stats.filter { $0.trend == .holding }.sorted { $0.adaptation > $1.adaptation }
        fading  = stats.filter { $0.trend == .fading }.sorted { $0.momentum < $1.momentum }
    }

    var growingCount: Int { growing.count }
    var holdingCount: Int { holding.count }
    var fadingCount: Int { fading.count }

    var hasAny: Bool { !growing.isEmpty || !holding.isEmpty || !fading.isEmpty }

    /// Lookup across all three buckets. Handy for tests and callers
    /// that want one muscle's trend directly.
    func stat(for muscle: Muscle) -> MuscleMomentumStat? {
        growing.first { $0.muscle == muscle }
            ?? holding.first { $0.muscle == muscle }
            ?? fading.first { $0.muscle == muscle }
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Replay the archive through the development model as of `now`
    /// and bucket every meaningfully-developed muscle by its growth
    /// trend. `bodyweight` (lb) scales unloaded movements via the
    /// same path the 3D body uses.
    func muscleMomentum(
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date()
    ) -> MuscleMomentumBoard {
        let state = MuscleDevelopment.simulate(from: self, bodyweight: bodyweight, now: now)
        let calendar = Calendar.current

        var stats: [MuscleMomentumStat] = []
        for (muscle, fiber) in state.fibers {
            let adaptation = Swift.min(1, Swift.max(0, fiber.adaptation))
            guard adaptation >= MuscleMomentumBoard.developmentFloor else { continue }

            let momentum = state.momentum(muscle)
            let trend: MomentumTrend
            if momentum > MuscleMomentumBoard.growingThreshold {
                trend = .growing
            } else if momentum < MuscleMomentumBoard.fadingThreshold {
                trend = .fading
            } else {
                trend = .holding
            }

            let days: Int?
            if let last = fiber.lastStimulated {
                days = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: last),
                    to: calendar.startOfDay(for: now)
                ).day
            } else {
                days = nil
            }

            stats.append(
                MuscleMomentumStat(
                    muscle: muscle,
                    trend: trend,
                    momentum: momentum,
                    adaptation: adaptation,
                    daysSinceLastTrained: days
                )
            )
        }

        return MuscleMomentumBoard(stats: stats)
    }
}

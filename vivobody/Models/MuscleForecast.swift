//
//  MuscleForecast.swift
//  vivobody
//
//  The forward-looking third muscle instrument. Balance asks "is the
//  dose enough?", momentum asks "is it growing right now?" — this asks
//  "if you stop training, what do you lose, and WHEN?"
//
//  It exploits a property the other two don't: `MuscleDevelopment` is
//  a date-driven dynamical system whose decay can be MARCHED INTO THE
//  FUTURE with no new stimulus. So we take the present state and step
//  it forward day by day (the decay is closed-form and additive, so
//  daily steps equal one big jump), watching each muscle's development
//  fade through its grace window and out the other side.
//
//  Two numbers fall out per muscle:
//    • daysUntilFade — the first future day its development drops below
//      a noticeable fraction of today's. Short = train it soon.
//    • projectedAdaptation — where it lands at the horizon, so the UI
//      can show how much is about to be lost.
//
//  Muscles too undeveloped to have anything to lose are dropped (same
//  floor as the momentum board). Pure value type on injected dates →
//  testable on a virtual clock (see `MuscleForecastTests`).
//

import Foundation

// MARK: - Per-muscle forecast

nonisolated struct MuscleForecastStat: Identifiable, Hashable {
    var id: Muscle { muscle }
    let muscle: Muscle
    /// Development now, `0...1`.
    let currentAdaptation: Double
    /// Projected development at the board's horizon, `0...1`.
    let projectedAdaptation: Double
    /// Days from now until development first dips below the fade
    /// threshold, untrained. `1...maxHorizon`.
    let daysUntilFade: Int
    let daysSinceLastTrained: Int?

    /// How much development is forecast to be lost by the horizon.
    var projectedLoss: Double { Swift.max(0, currentAdaptation - projectedAdaptation) }
}

// MARK: - Board

nonisolated struct MuscleForecastBoard {
    /// Horizon at which projected development is snapshotted for the
    /// "now → then" bar.
    static let horizonDays = 14
    /// How far forward the decay is simulated when locating fade onset.
    static let maxHorizonDays = 60
    /// Development dropping to this fraction of today's marks the start
    /// of a noticeable fade — the moment `daysUntilFade` records.
    static let fadeThreshold = 0.92
    /// At or below this many days to fade reads as urgent ("train soon").
    static let urgentDays = 7
    /// Muscles below this development have nothing meaningful to lose.
    static let developmentFloor = 0.03

    /// Every meaningfully-developed muscle, ordered by how soon it
    /// fades if left untrained — the decay leaderboard. Soonest first.
    let ranked: [MuscleForecastStat]
    let horizonDays: Int

    var hasDeveloped: Bool { !ranked.isEmpty }

    /// Days until the very first muscle starts fading, if any.
    var soonestFadeDays: Int? { ranked.first?.daysUntilFade }

    /// The forecast carries urgency when something fades within the week.
    var isUrgent: Bool { (soonestFadeDays ?? .max) <= Self.urgentDays }

    /// Lookup by muscle. Handy for tests and callers that want one
    /// muscle's outlook directly.
    func stat(for muscle: Muscle) -> MuscleForecastStat? {
        ranked.first { $0.muscle == muscle }
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Project the development model forward from `now` with no
    /// further training and report which muscles fade within
    /// `horizonDays`. `bodyweight` (lb) scales unloaded movements via
    /// the same path the 3D body and momentum board use.
    func muscleForecast(
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date(),
        horizonDays: Int = MuscleForecastBoard.horizonDays
    ) -> MuscleForecastBoard {
        var state = MuscleDevelopment.simulate(from: self, bodyweight: bodyweight, now: now)
        let calendar = Calendar.current

        // Snapshot today's development for every muscle worth tracking.
        var current: [Muscle: Double] = [:]
        var lastStim: [Muscle: Date] = [:]
        for (muscle, fiber) in state.fibers {
            let a = Swift.min(1, Swift.max(0, fiber.adaptation))
            guard a >= MuscleForecastBoard.developmentFloor else { continue }
            current[muscle] = a
            if let ts = fiber.lastStimulated { lastStim[muscle] = ts }
        }
        guard !current.isEmpty else {
            return MuscleForecastBoard(ranked: [], horizonDays: horizonDays)
        }

        // March decay forward, recording fade onset and the horizon snapshot.
        let maxH = MuscleForecastBoard.maxHorizonDays
        var daysUntilFade: [Muscle: Int] = [:]
        var projected: [Muscle: Double] = current
        for d in 1...maxH {
            guard let future = calendar.date(byAdding: .day, value: d, to: now) else { break }
            MuscleDevelopment.advance(&state, to: future)
            for (muscle, a0) in current {
                let a = Swift.min(1, Swift.max(0, state.fibers[muscle]?.adaptation ?? 0))
                if d == horizonDays { projected[muscle] = a }
                if daysUntilFade[muscle] == nil, a <= MuscleForecastBoard.fadeThreshold * a0 {
                    daysUntilFade[muscle] = d
                }
            }
        }

        var ranked: [MuscleForecastStat] = []
        for (muscle, a0) in current {
            let fadeDay = daysUntilFade[muscle] ?? (maxH + 1)

            let days: Int?
            if let ts = lastStim[muscle] {
                days = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: ts),
                    to: calendar.startOfDay(for: now)
                ).day
            } else {
                days = nil
            }

            ranked.append(
                MuscleForecastStat(
                    muscle: muscle,
                    currentAdaptation: a0,
                    projectedAdaptation: projected[muscle] ?? a0,
                    daysUntilFade: fadeDay,
                    daysSinceLastTrained: days
                )
            )
        }

        // Soonest to fade first; break ties by the larger forecast loss.
        ranked.sort { lhs, rhs in
            if lhs.daysUntilFade != rhs.daysUntilFade { return lhs.daysUntilFade < rhs.daysUntilFade }
            return lhs.projectedLoss > rhs.projectedLoss
        }

        return MuscleForecastBoard(ranked: ranked, horizonDays: horizonDays)
    }
}

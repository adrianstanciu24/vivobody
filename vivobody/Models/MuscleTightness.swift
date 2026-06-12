//
//  MuscleTightness.swift
//  vivobody
//
//  The per-muscle tightness roster behind the "Mobility" section of
//  the all-muscles breakdown. Where `BodyReadiness` rolls tightness up
//  to the six coarse groups for the Today body's one-line voice, this
//  keeps the individual regions — so the reference screen can name
//  exactly which muscles are short and owe some lengthening.
//
//  It reads the same tightness channel of `MuscleDevelopment` that
//  draws the cool strain rim on the figure, so the list and the body
//  always agree. Pure value type on injected dates — testable on a
//  virtual clock without a simulator.
//

import Foundation

// MARK: - Reading

nonisolated struct MuscleTightnessReading: Identifiable, Hashable {
    var id: Muscle { muscle }
    let muscle: Muscle
    /// Functional tightness, `0...1`.
    let tightness: Double
}

// MARK: - Board

nonisolated struct MuscleTightnessBoard {
    /// Tightness at/above which a muscle is worth flagging for
    /// mobility — matches `BodyReadiness.tightThreshold`.
    static let threshold = 0.25

    /// Flagged muscles, tightest first.
    let readings: [MuscleTightnessReading]

    var hasTight: Bool { !readings.isEmpty }
}

// MARK: - Aggregation

extension MuscleDevelopment.State {
    /// Per-muscle tightness from this state, keeping only muscles
    /// tight enough to flag. Reads the same channel that drives the
    /// figure's pulse, so the roster matches the body.
    func muscleTightness() -> MuscleTightnessBoard {
        let readings = fibers.compactMap { muscle, fiber -> MuscleTightnessReading? in
            let t = Swift.min(1, Swift.max(0, fiber.tightness))
            guard t >= MuscleTightnessBoard.threshold else { return nil }
            return MuscleTightnessReading(muscle: muscle, tightness: t)
        }
        .sorted { $0.tightness > $1.tightness }
        return MuscleTightnessBoard(readings: readings)
    }
}

extension Array where Element == WorkoutSession {
    /// Per-muscle tightness as of `now`. Convenience for one-shot
    /// callers and tests; screens that already hold a `State` should
    /// derive from it directly.
    func muscleTightness(now: Date = Date()) -> MuscleTightnessBoard {
        MuscleDevelopment.simulate(from: self, now: now).muscleTightness()
    }
}

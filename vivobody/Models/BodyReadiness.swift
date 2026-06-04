//
//  BodyReadiness.swift
//  vivobody
//
//  The "right now" voice of the 3D body. Where MuscleVolume asks
//  "is each muscle getting enough work?" and MuscleMomentum asks "is
//  it growing?", this asks the question you actually have standing in
//  the gym doorway: "what did I just hammer, and what's recovered and
//  ready to train again?"
//
//  It reads two channels of the same `MuscleDevelopment` model that
//  colours the figure, rolled up from individual muscles to the six
//  coarse `MuscleGroup`s the user thinks in:
//
//    • fatigue (acute, ~2-day half-life) → still FRESH from training.
//      This is the emissive bloom you can literally see glowing on
//      the body, so the words and the figure always agree.
//    • adaptation (development) with the bloom faded → recovered and
//      READY: built up, but rested enough to load again.
//    • little/no development → RESTING: nothing meaningful trained yet.
//
//  Pure value type driven by injected dates, so it's testable on a
//  virtual clock with no simulator — fast-forward recovery by passing
//  `now`.
//

import Foundation

// MARK: - State

/// How a muscle group reads at this moment.
nonisolated enum ReadinessState: Hashable {
    /// Worked recently — acute fatigue still high; the body glows here.
    case fresh
    /// Developed but recovered — the bloom has faded; load it again.
    case ready
    /// Little or no development yet — nothing to recover.
    case resting
}

// MARK: - Per-group reading

nonisolated struct GroupReadiness: Identifiable, Hashable {
    var id: MuscleGroup { group }
    let group: MuscleGroup
    let state: ReadinessState
    /// Acute fatigue (0…1) — the group's brightest member.
    let fatigue: Double
    /// Development (0…1) — the group's most-developed member.
    let adaptation: Double
    /// Whole days since any muscle in the group was last worked.
    /// `nil` only when the group has never been trained.
    let daysSinceLastTrained: Int?
}

// MARK: - Board

/// The six groups bucketed by readiness, in a stable display order.
nonisolated struct BodyReadiness {
    /// Fatigue at/above which a group still reads as FRESH. The
    /// fatigue channel halves every ~2 days, so this lands a hard
    /// session in the "fresh" band for roughly three days, then it
    /// graduates to "ready." Tunable here without touching the UI.
    static let freshFatigueThreshold = 0.30
    /// Development below this is treated as untrained — no recovery to
    /// speak of, so the group reads RESTING rather than READY.
    static let developmentFloor = 0.05

    /// One entry per `MuscleGroup`, in `MuscleGroup.allCases` order.
    let groups: [GroupReadiness]

    var fresh: [GroupReadiness] { groups.filter { $0.state == .fresh } }
    var ready: [GroupReadiness] { groups.filter { $0.state == .ready } }
    var resting: [GroupReadiness] { groups.filter { $0.state == .resting } }

    /// Has anything meaningful been trained at all?
    var hasTrained: Bool { groups.contains { $0.state != .resting } }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Replay the archive through the development model as of `now`
    /// and roll every muscle up into its coarse group, classifying
    /// each group as fresh / ready / resting. `bodyweight` (lb)
    /// scales unloaded movements via the same path the 3D body uses,
    /// so the readout and the figure are computed from one source.
    func bodyReadiness(
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date()
    ) -> BodyReadiness {
        let state = MuscleDevelopment.simulate(from: self, bodyweight: bodyweight, now: now)
        let calendar = Calendar.current

        // Roll the per-muscle fibers up to groups: a group is as fresh
        // and as developed as its brightest / most-developed member,
        // and was "last trained" whenever its most-recent member was.
        var fatigue: [MuscleGroup: Double] = [:]
        var adaptation: [MuscleGroup: Double] = [:]
        var lastTrained: [MuscleGroup: Date] = [:]

        for (muscle, fiber) in state.fibers {
            let group = muscle.group
            fatigue[group] = Swift.max(fatigue[group] ?? 0, clamp(fiber.fatigue))
            adaptation[group] = Swift.max(adaptation[group] ?? 0, clamp(fiber.adaptation))
            if let stamp = fiber.lastStimulated {
                if let prev = lastTrained[group] {
                    lastTrained[group] = Swift.max(prev, stamp)
                } else {
                    lastTrained[group] = stamp
                }
            }
        }

        let groups = MuscleGroup.allCases.map { group -> GroupReadiness in
            let f = fatigue[group] ?? 0
            let a = adaptation[group] ?? 0
            let days: Int? = lastTrained[group].map {
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: $0),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0
            }

            let state: ReadinessState
            if a < BodyReadiness.developmentFloor {
                state = .resting
            } else if f >= BodyReadiness.freshFatigueThreshold {
                state = .fresh
            } else {
                state = .ready
            }

            return GroupReadiness(
                group: group,
                state: state,
                fatigue: f,
                adaptation: a,
                daysSinceLastTrained: days
            )
        }

        return BodyReadiness(groups: groups)
    }
}

private func clamp(_ x: Double) -> Double { Swift.min(1, Swift.max(0, x)) }

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
//      The figure no longer visualises acute fatigue (it pulses for
//      tightness instead), so this drives the readout words only.
//    • adaptation (development) with the fatigue faded → recovered and
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
    /// Worked recently — acute fatigue still high.
    case fresh
    /// Developed but recovered — the fatigue has faded; load it again.
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
    /// Functional tightness (0…1) — the group's tightest member. The
    /// cool strain rim on the figure; flags that mobility is owed.
    let tightness: Double
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
    /// Tightness at/above which a group reads as TIGHT — worth a note
    /// that some mobility would help.
    static let tightThreshold = 0.25

    /// One entry per `MuscleGroup`, in `MuscleGroup.allCases` order.
    let groups: [GroupReadiness]

    var fresh: [GroupReadiness] { groups.filter { $0.state == .fresh } }
    var ready: [GroupReadiness] { groups.filter { $0.state == .ready } }
    var resting: [GroupReadiness] { groups.filter { $0.state == .resting } }

    /// Groups carrying enough tightness to flag, tightest first.
    var tight: [GroupReadiness] {
        groups.filter { $0.tightness >= Self.tightThreshold }
            .sorted { $0.tightness > $1.tightness }
    }

    /// Has anything meaningful been trained at all?
    var hasTrained: Bool { groups.contains { $0.state != .resting } }
}

// MARK: - Aggregation

extension MuscleDevelopment.State {
    /// Roll this development state up into its coarse groups,
    /// classifying each as fresh / ready / resting. Screens compute
    /// one `State` per data change and derive every board from it.
    func bodyReadiness(now: Date = Date()) -> BodyReadiness {
        let calendar = Calendar.current

        // Roll the per-muscle fibers up to groups: a group is as fresh
        // and as developed as its brightest / most-developed member,
        // and was "last trained" whenever its most-recent member was.
        var fatigue: [MuscleGroup: Double] = [:]
        var development: [MuscleGroup: Double] = [:]
        var tightness: [MuscleGroup: Double] = [:]
        var lastTrained: [MuscleGroup: Date] = [:]

        for (muscle, fiber) in fibers {
            let group = muscle.group
            fatigue[group] = Swift.max(fatigue[group] ?? 0, clamp(fiber.fatigue))
            development[group] = Swift.max(development[group] ?? 0, adaptation(muscle))
            tightness[group] = Swift.max(tightness[group] ?? 0, clamp(fiber.tightness))
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
            let a = development[group] ?? 0
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
                tightness: tightness[group] ?? 0,
                daysSinceLastTrained: days
            )
        }

        return BodyReadiness(groups: groups)
    }
}

extension Array where Element == WorkoutSession {
    /// Replay the archive through the development model as of `now`
    /// and roll every muscle up into its coarse group. Convenience for
    /// one-shot callers and tests; screens that already hold a `State`
    /// should derive from it directly.
    func bodyReadiness(now: Date = Date()) -> BodyReadiness {
        MuscleDevelopment.simulate(from: self, now: now).bodyReadiness(now: now)
    }
}

private func clamp(_ x: Double) -> Double { Swift.min(1, Swift.max(0, x)) }

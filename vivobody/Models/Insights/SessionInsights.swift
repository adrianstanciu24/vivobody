//
//  SessionInsights.swift
//  vivobody
//
//  Session-scoped reads layered on top of WorkoutSession for the
//  workout "receipt" (live WorkoutSummaryCard + History
//  SessionDetailScreen). Pure value types + computed extensions over
//  the model, no SwiftUI, so they're unit-testable in isolation.
//
//  Four reads, all derived from data already on the session:
//    • volumeDensity — tonnage per minute (reframes volume vs time).
//    • hardSetCount  — completed sets pushed to RIR ≤ 1.
//    • contributions — each exercise's share of the session's work,
//                      measured in its own "currency" (weight-volume
//                      for reps, hold-time for holds) so the two never
//                      get mashed onto one axis.
//    • adherence     — achieved top set vs the plan it was spawned
//                      from, per exercise.
//

import Foundation

// MARK: - Session-level intensity

extension WorkoutSession {
    /// Tonnage per minute, in canonical lb. Nil when there's no
    /// weight-volume (e.g. a holds-only session) or the clock hasn't
    /// meaningfully advanced — a sub-minute session would divide into
    /// a wildly inflated rate.
    var volumeDensity: Double? {
        let minutes = duration / 60
        guard minutes >= 1, totalVolume > 0 else { return nil }
        return totalVolume / minutes
    }

    /// True when any completed `.reps` set carries a real RIR reading
    /// — gates the hard-set count and effort line so they never show
    /// for sessions the user never rated.
    var hasLoggedRIR: Bool {
        exercises.contains { ex in
            ex.trackingMode == .reps &&
            ex.sets.contains { $0.isCompleted && $0.rirLogged }
        }
    }

    /// Completed sets taken to RIR ≤ 1 — the "hard sets" that drive
    /// most of the adaptive stimulus. Counts only real `rirLogged`
    /// readings on `.reps` work; timed holds carry no RIR.
    var hardSetCount: Int {
        exercises.reduce(0) { acc, ex in
            guard ex.trackingMode == .reps else { return acc }
            return acc + ex.sets.filter {
                $0.isCompleted && $0.rirLogged && $0.repsInReserve <= 1
            }.count
        }
    }
}

// MARK: - Waterfall (per-exercise share)

/// One exercise's contribution to the session, expressed as a share
/// within its own currency: reps exercises split the session's total
/// weight-volume; timed holds split the total hold-time. Keeping the
/// pools separate means a plank's bar reads against other holds, not
/// against a barbell squat it can't be compared to.
nonisolated struct SessionContribution: Hashable {
    /// Whether this exercise is measured in hold-time (true) or
    /// weight-volume (false).
    let isDuration: Bool
    /// The raw amount — canonical-lb volume for reps, seconds for
    /// holds.
    let metric: Double
    /// Fraction (0…1) of its currency's session total.
    let share: Double
}

extension WorkoutSession {
    /// Per-exercise contribution, keyed by exercise id. Reps and
    /// duration exercises are normalised against separate totals, so
    /// each pool's shares sum to 1 independently.
    func contributions() -> [UUID: SessionContribution] {
        var repsVolByID: [UUID: Double] = [:]
        var holdByID: [UUID: Double] = [:]

        for ex in orderedExercises {
            let completed = ex.sets.filter(\.isCompleted)
            if ex.trackingMode == .duration {
                holdByID[ex.id] = completed.reduce(0) { $0 + $1.duration }
            } else {
                repsVolByID[ex.id] = completed.reduce(0) { $0 + $1.weight * Double($1.reps) }
            }
        }

        let totalVol = repsVolByID.values.reduce(0, +)
        let totalHold = holdByID.values.reduce(0, +)

        var result: [UUID: SessionContribution] = [:]
        for (id, vol) in repsVolByID {
            result[id] = SessionContribution(
                isDuration: false,
                metric: vol,
                share: totalVol > 0 ? vol / totalVol : 0
            )
        }
        for (id, hold) in holdByID {
            result[id] = SessionContribution(
                isDuration: true,
                metric: hold,
                share: totalHold > 0 ? hold / totalHold : 0
            )
        }
        return result
    }
}

// MARK: - Planned vs actual

/// How an exercise's achieved top set compared to the plan it was
/// spawned from. Deltas are actual − planned, so positive means
/// "beat the plan". Only one axis is meaningful per mode.
nonisolated struct ExerciseAdherence: Hashable {
    let isDuration: Bool
    let weightDelta: Double          // lb, reps mode
    let repsDelta: Int               // reps mode
    let durationDelta: TimeInterval  // seconds, duration mode

    /// True when the achieved top set beat the plan on its meaningful
    /// axis.
    var beatPlan: Bool {
        isDuration ? durationDelta > 0 : (weightDelta > 0 || (weightDelta == 0 && repsDelta > 0))
    }

    /// True when the top set exactly matched the plan — nothing worth
    /// flagging (the badge view renders nothing).
    var isOnPlan: Bool {
        isDuration ? durationDelta == 0 : (weightDelta == 0 && repsDelta == 0)
    }
}

extension WorkoutSession {
    /// Planned-vs-actual for one exercise, or nil when it carries no
    /// plan (ad-hoc work with no snapshot) or hasn't been performed.
    /// The planned baseline is the heaviest / longest planned set
    /// captured at spawn time, paired weight+reps from the same slot
    /// so the comparison stays honest for pyramid programming.
    func adherence(for exercise: Exercise) -> ExerciseAdherence? {
        guard let top = topSet(for: exercise) else { return nil }
        let sets = exercise.orderedSets

        switch exercise.trackingMode {
        case .reps:
            let plannedTop = sets.max { a, b in
                if a.plannedWeight == b.plannedWeight { return a.plannedReps < b.plannedReps }
                return a.plannedWeight < b.plannedWeight
            }
            guard let plan = plannedTop, plan.plannedWeight > 0 || plan.plannedReps > 0 else {
                return nil
            }
            return ExerciseAdherence(
                isDuration: false,
                weightDelta: top.weight - plan.plannedWeight,
                repsDelta: top.reps - plan.plannedReps,
                durationDelta: 0
            )
        case .duration:
            let plannedDuration = sets.map(\.plannedDuration).max() ?? 0
            guard plannedDuration > 0 else { return nil }
            return ExerciseAdherence(
                isDuration: true,
                weightDelta: 0,
                repsDelta: 0,
                durationDelta: top.duration - plannedDuration
            )
        }
    }
}

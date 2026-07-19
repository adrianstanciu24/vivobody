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
//    • contributions — each eligible exercise's share of the session's
//                      work, measured in its own "currency" (comparable
//                      tonnage for dynamic strength, elapsed time for
//                      timed work) so the two never share one axis.
//    • adherence     — achieved top set vs the plan it was spawned
//                      from, per exercise.
//

import Foundation

// MARK: - Session-level intensity

extension WorkoutSession {
    /// Tonnage per minute, in canonical lb. Nil when comparable
    /// tonnage is partial/unavailable, when there's no weight-volume
    /// (e.g. a holds-only session), or when the clock hasn't
    /// meaningfully advanced. A density derived from a known subtotal
    /// would falsely look like a complete session rate.
    var volumeDensity: Double? {
        let minutes = duration / 60
        let tonnage = comparableTonnageSummary
        guard tonnage.availability == .complete,
              minutes >= 1,
              tonnage.knownSubtotal > 0 else { return nil }
        return tonnage.knownSubtotal / minutes
    }

    /// True when any completed, positive-repetition dynamic-strength
    /// set carries a real RIR reading — gates the hard-set count and
    /// effort line so they never show for sessions the user never rated.
    var hasLoggedRIR: Bool {
        exercises.contains { ex in
            ex.modality == .dynamicStrength &&
            ex.trackingMode == .reps &&
            ex.sets.contains { $0.isAnalyticsEligible && $0.reps > 0 && $0.rirLogged }
        }
    }

    /// Completed sets taken to RIR ≤ 1 — the "hard sets" that drive
    /// most of the adaptive stimulus. Counts only real `rirLogged`
    /// readings on positive `.reps` work; timed holds carry no RIR.
    var hardSetCount: Int {
        exercises.reduce(0) { acc, ex in
            guard ex.modality == .dynamicStrength,
                  ex.trackingMode == .reps else { return acc }
            return acc + ex.sets.filter {
                $0.isAnalyticsEligible && $0.reps > 0 &&
                $0.rirLogged && $0.repsInReserve <= 1
            }.count
        }
    }
}

// MARK: - Waterfall (per-exercise share)

/// One exercise's contribution to the session, expressed as a share
/// within its own currency: eligible dynamic-strength reps exercises
/// split comparable tonnage; timed exercises split elapsed duration.
/// Conditioning and mobility duration remains ordinary timed work,
/// while their reps work never masquerades as strength tonnage.
nonisolated struct SessionContribution: Hashable {
    /// Whether this exercise is measured in elapsed time (true) or
    /// comparable strength tonnage (false).
    let isDuration: Bool
    /// The raw amount — canonical-lb tonnage for eligible reps work,
    /// seconds for timed work.
    let metric: Double
    /// Fraction (0…1) of its currency's session total.
    let share: Double
}

extension WorkoutSession {
    /// Per-exercise contribution, keyed by exercise id. Comparable
    /// strength tonnage and elapsed duration are normalised against
    /// separate totals, so each pool's shares sum to 1 independently.
    /// Ineligible reps exercises are omitted rather than given a
    /// misleading zero-percent volume contribution. If any eligible
    /// tonnage is unknown, the whole tonnage pool is withheld because
    /// shares of a partial denominator are not meaningful; timed-work
    /// shares remain available in their independent pool.
    func contributions() -> [UUID: SessionContribution] {
        var tonnageByID: [UUID: Double] = [:]
        var durationByID: [UUID: Double] = [:]
        let canShowTonnageShares = comparableTonnageSummary.availability == .complete

        for ex in orderedExercises {
            let completed = ex.sets.filter(\.isAnalyticsEligible)
            if ex.trackingMode == .duration {
                durationByID[ex.id] = completed.reduce(0) { $0 + $1.duration }
            } else if canShowTonnageShares,
                      let tonnage = ex.completedComparableTonnage {
                tonnageByID[ex.id] = tonnage
            }
        }

        let totalTonnage = tonnageByID.values.reduce(0, +)
        let totalDuration = durationByID.values.reduce(0, +)

        var result: [UUID: SessionContribution] = [:]
        for (id, tonnage) in tonnageByID {
            result[id] = SessionContribution(
                isDuration: false,
                metric: tonnage,
                share: totalTonnage > 0 ? tonnage / totalTonnage : 0
            )
        }
        for (id, duration) in durationByID {
            result[id] = SessionContribution(
                isDuration: true,
                metric: duration,
                share: totalDuration > 0 ? duration / totalDuration : 0
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
        if isDuration {
            return weightDelta > 0
                || (weightDelta == 0 && durationDelta > 0)
        }
        return weightDelta > 0
            || (weightDelta == 0 && repsDelta > 0)
    }

    /// True when the top set exactly matched the plan — nothing worth
    /// flagging (the badge view renders nothing).
    var isOnPlan: Bool {
        isDuration
            ? (weightDelta == 0 && durationDelta == 0)
            : (weightDelta == 0 && repsDelta == 0)
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
            let comparesLoad = exercise.performanceSemanticKind.comparesLoad
            let plannedTop = sets.max { a, b in
                if comparesLoad {
                    let left = exercise.loadProfile.withinSnapshotLoadMarker(
                        loggedWeight: a.plannedWeight
                    ) ?? 0
                    let right = exercise.loadProfile.withinSnapshotLoadMarker(
                        loggedWeight: b.plannedWeight
                    ) ?? 0
                    if left == right { return a.plannedReps < b.plannedReps }
                    return left < right
                }
                if a.plannedReps == b.plannedReps { return a.plannedWeight < b.plannedWeight }
                return a.plannedReps < b.plannedReps
            }
            guard let plan = plannedTop, plan.plannedWeight > 0 || plan.plannedReps > 0 else {
                return nil
            }
            let weightDelta: Double
            if comparesLoad {
                weightDelta = exercise.loadProfile.withinSnapshotLoadDelta(
                    actualLoggedWeight: top.weight,
                    plannedLoggedWeight: plan.plannedWeight
                ) ?? 0
            } else {
                weightDelta = 0
            }
            return ExerciseAdherence(
                isDuration: false,
                weightDelta: weightDelta,
                repsDelta: top.reps - plan.plannedReps,
                durationDelta: 0
            )
        case .duration:
            let comparesLoad = exercise.performanceSemanticKind.comparesLoad
            let plannedTop = sets.max { a, b in
                if comparesLoad {
                    let left = exercise.loadProfile.withinSnapshotLoadMarker(
                        loggedWeight: a.plannedWeight
                    ) ?? 0
                    let right = exercise.loadProfile.withinSnapshotLoadMarker(
                        loggedWeight: b.plannedWeight
                    ) ?? 0
                    if left != right { return left < right }
                }
                return a.plannedDuration < b.plannedDuration
            }
            guard let plan = plannedTop, plan.plannedDuration > 0 else { return nil }
            let weightDelta = comparesLoad
                ? exercise.loadProfile.withinSnapshotLoadDelta(
                    actualLoggedWeight: top.weight,
                    plannedLoggedWeight: plan.plannedWeight
                ) ?? 0
                : 0
            return ExerciseAdherence(
                isDuration: true,
                weightDelta: weightDelta,
                repsDelta: 0,
                durationDelta: top.duration - plan.plannedDuration
            )
        }
    }
}

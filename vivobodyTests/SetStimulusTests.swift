//
//  SetStimulusTests.swift
//  vivobodyTests
//
//  Guards the hard-set currency
//  (specs/muscle-attention-simplification.md). The contract under
//  test: a completed working set is worth exactly 1.0, the only
//  discount is the user's own logged RIR (absence of a rating is
//  neutral), pricing is a pure per-set function with no cross-session
//  state, and only the two strength modality/tracking pairs earn
//  credit. Like every model suite: virtual clock, in-memory graphs.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct SetStimulusTests {

    // MARK: - Fixtures

    /// One completed set described in full.
    private struct SetSpec {
        var weight: Double
        var reps: Int
        var rir: Int? = nil        // nil = never rated (rirLogged false)
        var duration: TimeInterval = 0
        var isCompleted = true
    }

    private func lift(
        _ name: String,
        _ group: MuscleGroup,
        sets: [SetSpec],
        mode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            group: group,
            plannedSets: sets.count,
            plannedReps: sets.first?.reps ?? 8,
            plannedWeight: sets.first?.weight ?? 0,
            trackingMode: mode,
            modality: modality
        )
        for (spec, set) in zip(sets, ex.orderedSets) {
            set.weight = spec.weight
            set.reps = spec.reps
            set.duration = spec.duration
            set.isCompleted = spec.isCompleted
            if let rir = spec.rir {
                set.repsInReserve = rir
                set.rirLogged = true
            }
        }
        return ex
    }

    // MARK: - Anchors: a completed working set is worth exactly 1.0

    /// The calibration anchor: completed working sets with no RIR
    /// rated — the way most history is logged — price at exactly the
    /// raw set count.
    @Test func completedSetsPriceAtRawSetCount() {
        let ex = lift("Bench Press", .chest, sets: [
            SetSpec(weight: 135, reps: 8),
            SetSpec(weight: 135, reps: 8),
            SetSpec(weight: 135, reps: 8),
        ])
        #expect(abs(SetStimulus.setEquivalentCredit(for: ex) - 3.0) < 1e-9)
    }

    /// No load, rep-count, or history factor: a light set, a heavy
    /// single, and a working set all price identically. What the user
    /// did is counted; how impressive it was is not modelled.
    @Test func pricingIgnoresLoadAndRepCount() {
        let light = lift("Biceps Curl", .arms, sets: [SetSpec(weight: 5, reps: 12)])
        let single = lift("Biceps Curl", .arms, sets: [SetSpec(weight: 185, reps: 1)])
        let working = lift("Biceps Curl", .arms, sets: [SetSpec(weight: 50, reps: 8)])

        #expect(SetStimulus.setEquivalentCredit(for: light) == 1)
        #expect(SetStimulus.setEquivalentCredit(for: single) == 1)
        #expect(SetStimulus.setEquivalentCredit(for: working) == 1)
    }

    /// Pricing carries no cross-session state: the same exercise
    /// prices identically no matter what was logged before it.
    @Test func pricingIsStateless() {
        let heavy = lift("Bench Press", .chest, sets: [SetSpec(weight: 315, reps: 5)])
        let light = lift("Bench Press", .chest, sets: [SetSpec(weight: 95, reps: 10)])

        _ = SetStimulus.setEquivalentCredit(for: heavy)
        #expect(SetStimulus.setEquivalentCredit(for: light) == 1)
    }

    /// A timed hold counts as one set regardless of length.
    @Test func holdsPriceOnCompletionNotLength() {
        for duration in [5.0, 20, 90] {
            let ex = lift(
                "Plank",
                .core,
                sets: [SetSpec(weight: 0, reps: 0, duration: duration)],
                mode: .duration,
                modality: .isometricStrength
            )
            #expect(SetStimulus.setEquivalentCredit(for: ex) == 1)
        }
    }

    // MARK: - Role credit

    @Test func muscleRolesCreditPrimarySecondaryAndNotStabilizer() {
        let involvement = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorSternocostal, role: .primary),
            .init(muscle: .triceps, role: .secondary),
            .init(muscle: .serratus, role: .stabilizer),
        ])
        let ex = Exercise(
            name: "Role Fixture",
            group: .chest,
            plannedSets: 1,
            plannedReps: 8,
            plannedWeight: 100,
            muscleInvolvement: involvement
        )
        ex.orderedSets.forEach { $0.isCompleted = true }

        let credit = SetStimulus.credit(for: ex)
        #expect(credit[.pectoralisMajorSternocostal] == 1)
        #expect(credit[.triceps] == 0.5)
        #expect(credit[.serratus] == nil)
    }

    // MARK: - Modality gates

    @Test func powerEarnsNoHardSetCredit() {
        let exercise = lift("Power Fixture", .core, sets: [
            SetSpec(weight: 25, reps: 10),
        ], modality: .power)

        #expect(SetStimulus.setEquivalentCredit(for: exercise) == 0)
        #expect(SetStimulus.credit(for: exercise).isEmpty)
    }

    @Test func onlyExactStrengthModalityAndTrackingPairsEarnCredit() {
        let mismatches = [
            lift(
                "Dynamic Duration Mismatch",
                .core,
                sets: [SetSpec(weight: 25, reps: 0, duration: 30)],
                mode: .duration,
                modality: .dynamicStrength
            ),
            lift(
                "Isometric Reps Mismatch",
                .core,
                sets: [SetSpec(weight: 25, reps: 10)],
                mode: .reps,
                modality: .isometricStrength
            ),
        ]

        for exercise in mismatches {
            #expect(SetStimulus.setEquivalentCredit(for: exercise) == 0)
        }
    }

    @Test func zeroAndIncompleteSetsEarnNoCredit() {
        let invalid = [
            lift("Zero Reps", .chest, sets: [SetSpec(weight: 135, reps: 0)]),
            lift(
                "Zero Duration",
                .core,
                sets: [SetSpec(weight: 25, reps: 0, duration: 0)],
                mode: .duration,
                modality: .isometricStrength
            ),
            lift("Incomplete Reps", .chest, sets: [
                SetSpec(weight: 135, reps: 8, isCompleted: false),
            ]),
            lift(
                "Incomplete Duration",
                .core,
                sets: [SetSpec(weight: 25, reps: 0, duration: 30, isCompleted: false)],
                mode: .duration,
                modality: .isometricStrength
            ),
        ]

        for exercise in invalid {
            #expect(SetStimulus.setEquivalentCredit(for: exercise) == 0)
        }
    }

    // MARK: - Effort curve (the one discount)

    /// RIR 0–2 all count as full hard sets — the landmark band.
    @Test func nearFailureRIRKeepsFullCredit() {
        for rir in 0...2 {
            let ex = lift("Bench Press", .chest, sets: [SetSpec(weight: 135, reps: 8, rir: rir)])
            #expect(abs(SetStimulus.setEquivalentCredit(for: ex) - 1.0) < 1e-9)
        }
    }

    /// A default RIR value the user never touched is NOT a reading —
    /// even a stored 5 prices neutral when `rirLogged` is false.
    @Test func unloggedRIRIsNeutral() {
        let ex = lift("Bench Press", .chest, sets: [SetSpec(weight: 135, reps: 8)])
        ex.orderedSets[0].repsInReserve = 5   // stored but never rated
        #expect(abs(SetStimulus.setEquivalentCredit(for: ex) - 1.0) < 1e-9)
    }

    @Test func effortDecaysBeyondRIR2() {
        #expect(SetStimulus.effortFactor(rir: 2, logged: true) == 1.0)
        #expect(abs(SetStimulus.effortFactor(rir: 3, logged: true) - 0.8) < 1e-9)
        #expect(abs(SetStimulus.effortFactor(rir: 5, logged: true) - 0.512) < 1e-9)
        #expect(SetStimulus.effortFactor(rir: 5, logged: false) == 1.0)
    }

    /// The rated discount flows through whole-exercise pricing.
    @Test func ratedEasySetsAreDiscounted() {
        let ex = lift("Bench Press", .chest, sets: [
            SetSpec(weight: 135, reps: 8, rir: 1),
            SetSpec(weight: 135, reps: 8, rir: 5),
        ])
        #expect(abs(SetStimulus.setEquivalentCredit(for: ex) - 1.512) < 1e-9)
    }

    // MARK: - Currency agreement across surfaces

    /// `muscleVolume` and a `sessionStimulus` replay price a
    /// multi-session history identically, muscle for muscle.
    @Test func volumeAndDevelopmentAgreeAcrossSessions() {
        func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
            let s = WorkoutSession(exercises: exercises, startedAt: date)
            s.completedAt = date
            return s
        }
        let origin = Date(timeIntervalSince1970: 1_700_000_000)
        let history = [
            session(at: origin, [lift("Bench Press", .chest, sets: [
                SetSpec(weight: 135, reps: 8), SetSpec(weight: 185, reps: 6, rir: 1),
            ])]),
            session(at: origin.addingTimeInterval(3 * 86_400), [lift("Bench Press", .chest, sets: [
                SetSpec(weight: 95, reps: 10), SetSpec(weight: 185, reps: 6, rir: 4),
            ])]),
        ]

        var replayed: [Muscle: Double] = [:]
        for s in history {
            for (m, v) in MuscleDevelopment.sessionStimulus(s) {
                replayed[m, default: 0] += v
            }
        }

        let stats = history.muscleVolume(now: origin.addingTimeInterval(3 * 86_400))
        for stat in stats {
            #expect(abs(stat.effectiveSets - (replayed[stat.muscle] ?? 0)) < 1e-9)
        }
    }
}

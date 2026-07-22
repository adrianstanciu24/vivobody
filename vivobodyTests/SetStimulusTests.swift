//
//  SetStimulusTests.swift
//  vivobodyTests
//
//  Guards the hard-set-equivalent currency (specs/hard-set-currency.md).
//  The contract under test: a normal hard working set is worth exactly
//  1.0 (the neutral anchor that keeps the volume landmarks and every
//  existing colour calibrated), absence of signal is always neutral
//  (unlogged RIR, unavailable load, first instance), and the factor
//  curves demote exactly the junk they were built for — warm-up loads,
//  token weights, heavy singles, short/light holds, and sets far from
//  failure. Load references must be causal (a stronger set raises the
//  bar only for what follows) and must relax after a layoff (decaying
//  max, not all-time max). Like every model suite: virtual clock,
//  in-memory graphs.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct SetStimulusTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

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

    /// Total hard-set equivalents before role-based muscle credit.
    private func total(_ calculator: inout SetStimulus.Calculator, _ ex: Exercise, at date: Date) -> Double {
        calculator.setEquivalentCredit(for: ex, at: date)
    }

    // MARK: - Anchors: a hard working set is worth exactly 1.0

    /// The calibration anchor: working reps at working weight with no
    /// RIR rated — the way most history is logged — prices at exactly
    /// the raw set count, so existing colours and bars don't move.
    @Test func hardWorkingSetsPriceAtRawSetCount() {
        var calc = SetStimulus.Calculator()
        let ex = lift("Bench Press", .chest, sets: [
            SetSpec(weight: 135, reps: 8),
            SetSpec(weight: 135, reps: 8),
            SetSpec(weight: 135, reps: 8),
        ])
        #expect(abs(total(&calc, ex, at: day(0)) - 3.0) < 1e-9)
    }

    @Test func wholeExerciseCreditMatchesPreInvolvementTotal() {
        let ex = lift("Bench Press", .chest, sets: [
            SetSpec(weight: 135, reps: 8),
            SetSpec(weight: 135, reps: 8),
            SetSpec(weight: 135, reps: 8),
        ])
        var calculator = SetStimulus.Calculator()
        #expect(abs(calculator.setEquivalentCredit(for: ex, at: day(0)) - 3.0) < 1e-9)
    }

    @Test func muscleRolesCreditPrimarySecondaryAndNotStabilizer() {
        let involvement = Muscle.Involvement(contributions: [
            .init(muscle: .pectorals, role: .primary),
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

        var calculator = SetStimulus.Calculator()
        let credit = calculator.credit(for: ex, at: day(0))
        #expect(credit[.pectorals] == 1)
        #expect(credit[.triceps] == 0.5)
        #expect(credit[.serratus] == nil)
    }

    @Test func powerMobilityAndConditioningEarnNoHardSetCredit() {
        for modality in [ExerciseModality.power, .mobility, .conditioning] {
            let ex = lift("Non-strength Fixture", .core, sets: [
                SetSpec(weight: 25, reps: 10),
            ], modality: modality)
            var calculator = SetStimulus.Calculator()
            #expect(calculator.setEquivalentCredit(for: ex, at: day(0)) == 0)
            #expect(calculator.credit(for: ex, at: day(0)).isEmpty)
        }
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
            var calculator = SetStimulus.Calculator()
            #expect(calculator.setEquivalentCredit(for: exercise, at: day(0)) == 0)
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
            var calculator = SetStimulus.Calculator()
            #expect(calculator.setEquivalentCredit(for: exercise, at: day(0)) == 0)
        }
    }

    /// RIR 0–2 all count as full hard sets — the landmark band.
    @Test func nearFailureRIRKeepsFullCredit() {
        for rir in 0...2 {
            var calc = SetStimulus.Calculator()
            let ex = lift("Bench Press", .chest, sets: [SetSpec(weight: 135, reps: 8, rir: rir)])
            #expect(abs(total(&calc, ex, at: day(0)) - 1.0) < 1e-9)
        }
    }

    /// A default RIR value the user never touched is NOT a reading —
    /// even a stored 5 prices neutral when `rirLogged` is false.
    @Test func unloggedRIRIsNeutral() {
        var calc = SetStimulus.Calculator()
        let ex = lift("Bench Press", .chest, sets: [SetSpec(weight: 135, reps: 8)])
        ex.orderedSets[0].repsInReserve = 5   // stored but never rated
        #expect(abs(total(&calc, ex, at: day(0)) - 1.0) < 1e-9)
    }

    /// Detached fixtures have no measured bodyweight. Bodyweight-
    /// dependent load is unavailable and therefore neutral forever,
    /// rather than being calculated from an invented default.
    @Test func unknownBodyweightSetsAreLoadNeutral() {
        var calc = SetStimulus.Calculator()
        for d in [0.0, 3, 6] {
            let ex = lift("Pull-ups", .back, sets: [SetSpec(weight: 0, reps: 10)])
            ex.loadMode = .bodyweightAdded
            ex.bodyweightFraction = 1
            #expect(abs(total(&calc, ex, at: day(d)) - 1.0) < 1e-9)
        }
    }

    @Test func machineAssistanceUsesInverseLoadPolarity() {
        func assisted(_ assistance: Double) -> Exercise {
            let exercise = lift("Assistance Fixture", .back, sets: [
                SetSpec(weight: assistance, reps: 8),
            ])
            exercise.loadMode = .assistanceSubtracted
            exercise.bodyweightFraction = 1
            exercise.session = WorkoutSession(bodyweightAtStart: 100)
            return exercise
        }

        var calculator = SetStimulus.Calculator()
        _ = total(&calculator, assisted(40), at: day(0))
        let moreAssistance = total(&calculator, assisted(80), at: day(3))
        let lessAssistance = total(&calculator, assisted(20), at: day(6))

        #expect(moreAssistance < 1)
        #expect(lessAssistance == 1)
    }

    @Test func nonComparableLoadRemainsNeutral() {
        var calculator = SetStimulus.Calculator()
        let exercise = lift("Band Fixture", .back, sets: [
            SetSpec(weight: 1, reps: 8),
        ])
        exercise.loadMode = .nonComparable
        #expect(total(&calculator, exercise, at: day(0)) == 1)
    }

    // MARK: - Effort curve

    @Test func effortDecaysBeyondRIR2() {
        #expect(SetStimulus.effortFactor(rir: 2, logged: true) == 1.0)
        #expect(abs(SetStimulus.effortFactor(rir: 3, logged: true) - 0.8) < 1e-9)
        #expect(abs(SetStimulus.effortFactor(rir: 5, logged: true) - 0.512) < 1e-9)
        #expect(SetStimulus.effortFactor(rir: 5, logged: false) == 1.0)
    }

    // MARK: - Rep curve

    @Test func lowRepSetsEarnPartialCredit() {
        #expect(SetStimulus.repFactor(reps: 1) == 0.5)     // heavy single = half a hard set
        #expect(abs(SetStimulus.repFactor(reps: 3) - 0.75) < 1e-9)
        #expect(SetStimulus.repFactor(reps: 5) == 1.0)
        #expect(SetStimulus.repFactor(reps: 20) == 1.0)    // a hard set is a hard set — no tonnage bonus
    }

    @Test func holdsPriceOnLength() {
        #expect(SetStimulus.holdFactor(duration: 5) == 0.5)    // floored
        #expect(abs(SetStimulus.holdFactor(duration: 15) - 0.75) < 1e-9)
        #expect(SetStimulus.holdFactor(duration: 20) == 1.0)
        #expect(SetStimulus.holdFactor(duration: 90) == 1.0)
    }

    /// The first valid loaded hold is neutral on load and seeds its
    /// own isometric reference, while duration still controls credit.
    @Test func firstLoadedIsometricUsesDurationAndSeedsLoadReference() {
        var calc = SetStimulus.Calculator()
        let ex = lift(
            "Weighted Plank",
            .core,
            sets: [SetSpec(weight: 100, reps: 0, duration: 15)],
            mode: .duration,
            modality: .isometricStrength
        )
        #expect(abs(total(&calc, ex, at: day(0)) - 0.75) < 1e-9)
    }

    @Test func loadedIsometricReflectsBothLoadAndDuration() {
        var calculator = SetStimulus.Calculator()
        let seed = lift(
            "Weighted Plank",
            .core,
            sets: [SetSpec(weight: 100, reps: 0, duration: 30)],
            mode: .duration,
            modality: .isometricStrength
        )
        #expect(total(&calculator, seed, at: day(0)) == 1)

        let lighterAndShorter = lift(
            "Weighted Plank",
            .core,
            sets: [SetSpec(weight: 20, reps: 0, duration: 15)],
            mode: .duration,
            modality: .isometricStrength
        )
        // 0.75 duration factor × 0.30 load floor.
        #expect(abs(total(&calculator, lighterAndShorter, at: day(0)) - 0.225) < 1e-9)
    }

    @Test func invalidIsometricDoesNotSeedLoadReference() {
        var calculator = SetStimulus.Calculator()
        let invalid = lift(
            "Weighted Hold",
            .core,
            sets: [SetSpec(weight: 100, reps: 0, duration: 0)],
            mode: .duration,
            modality: .isometricStrength
        )
        #expect(total(&calculator, invalid, at: day(0)) == 0)

        let firstValid = lift(
            "Weighted Hold",
            .core,
            sets: [SetSpec(weight: 20, reps: 0, duration: 30)],
            mode: .duration,
            modality: .isometricStrength
        )
        #expect(total(&calculator, firstValid, at: day(3)) == 1)
    }

    @Test func isometricLoadReferenceRelaxesAfterALayoff() {
        var calculator = SetStimulus.Calculator()
        let peak = lift(
            "Weighted Hold",
            .core,
            sets: [SetSpec(weight: 100, reps: 0, duration: 30)],
            mode: .duration,
            modality: .isometricStrength
        )
        _ = total(&calculator, peak, at: day(0))

        let comeback = lift(
            "Weighted Hold",
            .core,
            sets: [SetSpec(weight: 60, reps: 0, duration: 30)],
            mode: .duration,
            modality: .isometricStrength
        )
        #expect(total(&calculator, comeback, at: day(180)) == 1)
    }

    @Test func nonComparableIsometricLoadStaysDurationOnly() {
        func bandHold(_ resistance: Double) -> Exercise {
            let exercise = lift(
                "Band Hold",
                .shoulders,
                sets: [SetSpec(weight: resistance, reps: 0, duration: 15)],
                mode: .duration,
                modality: .isometricStrength
            )
            exercise.loadMode = .nonComparable
            return exercise
        }

        var calculator = SetStimulus.Calculator()
        #expect(total(&calculator, bandHold(100), at: day(0)) == 0.75)
        #expect(total(&calculator, bandHold(1), at: day(3)) == 0.75)
    }

    @Test func unknownBodyweightIsometricLoadStaysDurationOnly() {
        func bodyweightHold(_ addedLoad: Double) -> Exercise {
            let exercise = lift(
                "Bodyweight Hold",
                .core,
                sets: [SetSpec(weight: addedLoad, reps: 0, duration: 15)],
                mode: .duration,
                modality: .isometricStrength
            )
            exercise.loadMode = .bodyweightAdded
            exercise.bodyweightFraction = 1
            return exercise
        }

        var calculator = SetStimulus.Calculator()
        #expect(total(&calculator, bodyweightHold(100), at: day(0)) == 0.75)
        #expect(total(&calculator, bodyweightHold(0), at: day(3)) == 0.75)
    }

    // MARK: - Load curve

    @Test func loadRampSpansFloorToFullCredit() {
        #expect(abs(SetStimulus.loadFactor(e1RMRatio: 0.2) - 0.3) < 1e-9)
        #expect(abs(SetStimulus.loadFactor(e1RMRatio: 0.4) - 0.3) < 1e-9)
        #expect(abs(SetStimulus.loadFactor(e1RMRatio: 0.55) - 0.65) < 1e-9)
        #expect(SetStimulus.loadFactor(e1RMRatio: 0.7) == 1.0)
        #expect(SetStimulus.loadFactor(e1RMRatio: 1.5) == 1.0)
    }

    /// The 5 lb curl problem: once working strength is on record,
    /// token weights are demoted to the load floor.
    @Test func tokenWeightIsDemotedAgainstHistory() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Biceps Curl", .arms, sets: [SetSpec(weight: 50, reps: 8)]), at: day(0))

        let token = lift("Biceps Curl", .arms, sets: [SetSpec(weight: 5, reps: 8)])
        let credit = total(&calc, token, at: day(3))
        #expect(abs(credit - 0.3) < 0.01)   // load floor; effort/reps neutral
    }

    /// Warm-up ramps read as fractions of a working set even when RIR
    /// is never logged.
    @Test func warmupsAreDemotedWithoutRIR() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Bench Press", .chest, sets: [SetSpec(weight: 275, reps: 6)]), at: day(0))

        let session = lift("Bench Press", .chest, sets: [
            SetSpec(weight: 95, reps: 10),    // warm-up
            SetSpec(weight: 275, reps: 6),    // work
            SetSpec(weight: 275, reps: 6),    // work
        ])
        let credit = total(&calc, session, at: day(3))
        #expect(credit > 2.0)    // working sets kept whole
        #expect(credit < 2.5)    // the warm-up did not count as a full set
    }

    // MARK: - Reference causality

    /// A PR set is judged against PRIOR history — full credit — and
    /// only raises the bar for the sets after it.
    @Test func prSetGetsFullCreditThenRaisesTheBar() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Bench Press", .chest, sets: [SetSpec(weight: 135, reps: 8)]), at: day(0))

        // PR day: the jump itself full-credits…
        let pr = lift("Bench Press", .chest, sets: [SetSpec(weight: 225, reps: 8)])
        #expect(abs(total(&calc, pr, at: day(3)) - 1.0) < 1e-9)

        // …and the old working weight is now judged against the new bar.
        let old = lift("Bench Press", .chest, sets: [SetSpec(weight: 135, reps: 8)])
        let credit = total(&calc, old, at: day(6))
        #expect(credit < 0.85)
        #expect(credit > 0.5)
    }

    /// The first-ever instance of a lift is neutral and seeds the
    /// reference for everything after.
    @Test func firstInstanceIsNeutralAndSeeds() {
        var calc = SetStimulus.Calculator()
        let first = lift("Goblet Squat", .legs, sets: [SetSpec(weight: 53, reps: 10)])
        #expect(abs(total(&calc, first, at: day(0)) - 1.0) < 1e-9)

        let token = lift("Goblet Squat", .legs, sets: [SetSpec(weight: 5, reps: 10)])
        #expect(total(&calc, token, at: day(3)) < 0.35)
    }

    /// References are per-exercise: a heavy squat never demotes a curl.
    @Test func referencesAreScopedPerExercise() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Back Squat", .legs, sets: [SetSpec(weight: 315, reps: 5)]), at: day(0))

        let curl = lift("Biceps Curl", .arms, sets: [SetSpec(weight: 30, reps: 10)])
        #expect(abs(total(&calc, curl, at: day(1)) - 1.0) < 1e-9)
    }

    // MARK: - Reference decay (the comeback lifter)

    /// The bar relaxes on a layoff: honest working sets after six
    /// months off are NOT demoted against the year-old peak…
    @Test func referenceRelaxesAfterALayoff() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Bench Press", .chest, sets: [SetSpec(weight: 315, reps: 5)]), at: day(0))

        let comeback = lift("Bench Press", .chest, sets: [SetSpec(weight: 185, reps: 5)])
        #expect(abs(total(&calc, comeback, at: day(180)) - 1.0) < 1e-9)
    }

    /// …while the same drop-off WITHIN a training block still reads
    /// as the light work it is.
    @Test func freshReferenceStillDemotesLightWork() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Bench Press", .chest, sets: [SetSpec(weight: 315, reps: 5)]), at: day(0))

        let light = lift("Bench Press", .chest, sets: [SetSpec(weight: 185, reps: 5)])
        let credit = total(&calc, light, at: day(7))
        #expect(credit < 0.9)
        #expect(credit > 0.6)
    }

    // MARK: - Floor

    /// Even maximal junk (token weight, single rep, RIR 5) registers —
    /// "did something" never reads identical to "did nothing."
    @Test func junkSetsFloorAboveZero() {
        var calc = SetStimulus.Calculator()
        _ = total(&calc, lift("Biceps Curl", .arms, sets: [SetSpec(weight: 50, reps: 8)]), at: day(0))

        let junk = lift("Biceps Curl", .arms, sets: [SetSpec(weight: 5, reps: 1, rir: 5)])
        let credit = total(&calc, junk, at: day(3))
        #expect(abs(credit - 0.1) < 1e-9)   // the stimulus floor, exactly
    }

    // MARK: - Currency agreement across surfaces

    /// `muscleVolume` and a chronological `sessionStimulus` replay
    /// price a multi-session history identically, muscle for muscle —
    /// including the causal load references.
    @Test func volumeAndDevelopmentAgreeAcrossSessions() {
        func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
            let s = WorkoutSession(exercises: exercises, startedAt: date)
            s.completedAt = date
            return s
        }
        let history = [
            session(at: day(0), [lift("Bench Press", .chest, sets: [
                SetSpec(weight: 135, reps: 8), SetSpec(weight: 185, reps: 6, rir: 1),
            ])]),
            session(at: day(3), [lift("Bench Press", .chest, sets: [
                SetSpec(weight: 95, reps: 10), SetSpec(weight: 185, reps: 6, rir: 4),
            ])]),
        ]

        var calc = SetStimulus.Calculator()
        var replayed: [Muscle: Double] = [:]
        for s in history {
            let stim = MuscleDevelopment.sessionStimulus(s, at: s.completedAt!, calculator: &calc)
            for (m, v) in stim { replayed[m, default: 0] += v }
        }

        let stats = history.muscleVolume(now: day(3))
        for stat in stats {
            #expect(abs(stat.effectiveSets - (replayed[stat.muscle] ?? 0)) < 1e-9)
        }
    }
}

//
//  SessionInsightsTests.swift
//  vivobodyTests
//
//  Guards the four session-scoped reads behind the workout receipt:
//  density (tonnage per minute), hard-set count (RIR ≤ 1), the
//  per-exercise waterfall (shares within separate weight-volume and
//  hold-time pools), and planned-vs-actual adherence.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct SessionInsightsTests {

    // MARK: - Builders

    /// A completed session spanning `minutes` of wall-clock time.
    private func session(
        minutes: Double,
        _ exercises: [Exercise],
        bodyweightAtStart: Double = ExerciseLoad.unknownBodyweight
    ) -> WorkoutSession {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let s = WorkoutSession(
            exercises: exercises,
            bodyweightAtStart: bodyweightAtStart,
            startedAt: start
        )
        s.completedAt = start.addingTimeInterval(minutes * 60)
        return s
    }

    /// A reps exercise with explicit per-set (weight, reps, rir?,
    /// completed) and an optional uniform plan snapshot.
    private func lift(
        _ name: String = "Bench Press",
        _ group: MuscleGroup = .chest,
        sets: [(weight: Double, reps: Int, rir: Int?, completed: Bool)],
        planWeight: Double = 0,
        planReps: Int = 0,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            group: group,
            plannedSets: 0,
            plannedWeight: 0,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
        for (i, s) in sets.enumerated() {
            ex.sets.append(
                WorkoutSet(
                    weight: s.weight,
                    reps: s.reps,
                    isCompleted: s.completed,
                    repsInReserve: s.rir ?? 2,
                    rirLogged: s.rir != nil,
                    sortOrder: i,
                    plannedWeight: planWeight,
                    plannedReps: planReps
                )
            )
        }
        return ex
    }

    private func hold(
        _ name: String,
        seconds: [TimeInterval],
        planDuration: TimeInterval = 0
    ) -> Exercise {
        let ex = Exercise(name: name, group: .core, plannedSets: 0, plannedWeight: 0, trackingMode: .duration)
        for (i, sec) in seconds.enumerated() {
            ex.sets.append(
                WorkoutSet(weight: 0, reps: 0, duration: sec, isCompleted: true, sortOrder: i, plannedDuration: planDuration)
            )
        }
        return ex
    }

    // MARK: - Density

    @Test func densityIsVolumePerMinute() {
        // 3 sets × 100 × 10 = 3000 lb over 30 min → 100 lb/min.
        let s = session(minutes: 30, [lift(sets: [(100, 10, nil, true), (100, 10, nil, true), (100, 10, nil, true)])])
        #expect(abs((s.volumeDensity ?? 0) - 100) < 0.001)
    }

    @Test func densityNilForSubMinuteSession() {
        let s = session(minutes: 0.5, [lift(sets: [(100, 10, nil, true)])])
        #expect(s.volumeDensity == nil)
    }

    @Test func densityNilForHoldsOnlySession() {
        let s = session(minutes: 10, [hold("Plank", seconds: [60, 60])])
        #expect(s.volumeDensity == nil)
    }

    @Test func totalVolumeUsesEffectiveLoadPolarity() {
        let weighted = lift(
            "Weighted Pull-Up",
            .back,
            sets: [(25, 10, nil, true)],
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        let assisted = lift(
            "Assisted Pull-Up",
            .back,
            sets: [(55, 10, nil, true)],
            loadMode: .assistanceSubtracted,
            bodyweightFraction: 1
        )
        let s = session(minutes: 20, [weighted, assisted], bodyweightAtStart: 155)

        // Captured body weight is 155 lb: (155 + 25) × 10 +
        // (155 − 55) × 10 = 2,800 lb.
        #expect(s.totalVolume == 2_800)
    }

    @Test func totalVolumeExcludesNonStrengthAndNonComparableReps() {
        let conditioning = lift(
            "Burpee",
            sets: [(100, 10, nil, true)],
            modality: .conditioning
        )
        let mobility = lift(
            "Shoulder CAR",
            sets: [(100, 10, nil, true)],
            modality: .mobility
        )
        let invalidIsometricReps = lift(
            "Static Hold",
            sets: [(100, 10, nil, true)],
            modality: .isometricStrength
        )
        let banded = lift(
            "Band Row",
            .back,
            sets: [(100, 10, nil, true)],
            loadMode: .nonComparable
        )
        let dynamic = lift(sets: [(100, 10, nil, true)])
        let s = session(minutes: 20, [conditioning, mobility, invalidIsometricReps, banded, dynamic])

        #expect(s.totalVolume == 1_000)
    }

    @Test func unknownBodyweightMakesComparableTonnageUnavailable() {
        let pullUp = lift(
            "Weighted Pull-Up",
            .back,
            sets: [(25, 8, nil, true)],
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        let s = session(minutes: 20, [pullUp])

        #expect(s.comparableTonnageSummary.knownSubtotal == 0)
        #expect(s.comparableTonnageSummary.availability == .unavailable)
        #expect(s.totalVolume == 0)
        #expect(s.volumeDensity == nil)
        #expect(s.contributions()[pullUp.id] == nil)
    }

    @Test func mixedKnownAndUnknownTonnageExposesOnlyAPartialSubtotal() {
        let row = lift(
            "Barbell Row",
            .back,
            sets: [(100, 10, nil, true)]
        )
        let pullUp = lift(
            "Weighted Pull-Up",
            .back,
            sets: [(25, 8, nil, true)],
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        let plank = hold("Plank", seconds: [60])
        let s = session(minutes: 20, [row, pullUp, plank])
        let contributions = s.contributions()

        #expect(s.comparableTonnageSummary.knownSubtotal == 1_000)
        #expect(s.comparableTonnageSummary.availability == .partial)
        #expect(s.totalVolume == 1_000)
        #expect(s.volumeDensity == nil)
        #expect(contributions[row.id] == nil)
        #expect(contributions[pullUp.id] == nil)
        #expect(contributions[plank.id]?.isDuration == true)
        #expect(contributions[plank.id]?.share == 1)
    }

    @Test func nonComparableWorkIsExcludedWithoutMakingTonnageMissing() {
        let bandRow = lift(
            "Band Row",
            .back,
            sets: [(3, 12, nil, true)],
            loadMode: .nonComparable
        )
        let s = session(minutes: 20, [bandRow])

        #expect(s.comparableTonnageSummary.knownSubtotal == 0)
        #expect(s.comparableTonnageSummary.availability == .complete)
        #expect(s.totalVolume == 0)
        #expect(s.volumeDensity == nil)
        #expect(s.contributions()[bandRow.id] == nil)
    }

    // MARK: - Hard sets

    @Test func hardSetsCountRIRAtOrBelowOne() {
        let s = session(minutes: 20, [lift(sets: [
            (100, 8, 0, true),   // hard
            (100, 8, 1, true),   // hard
            (100, 8, 2, true),   // not hard
            (100, 8, nil, true)  // unrated → ignored
        ])])
        #expect(s.hardSetCount == 2)
        #expect(s.hasLoggedRIR == true)
    }

    @Test func noLoggedRIRMeansNoHardSets() {
        let s = session(minutes: 20, [lift(sets: [(100, 8, nil, true), (100, 8, nil, true)])])
        #expect(s.hasLoggedRIR == false)
        #expect(s.hardSetCount == 0)
    }

    @Test func conditioningRIRDoesNotCountAsStrengthHardSets() {
        let exercise = lift(sets: [(100, 8, 0, true)])
        exercise.modality = .conditioning
        let s = session(minutes: 20, [exercise])
        #expect(!s.hasLoggedRIR)
        #expect(s.hardSetCount == 0)
    }

    @Test func invalidIsometricRepsRIRDoesNotCountAsHardSets() {
        let exercise = lift(sets: [(100, 8, 0, true)])
        exercise.modality = .isometricStrength
        let s = session(minutes: 20, [exercise])

        #expect(!s.hasLoggedRIR)
        #expect(s.hardSetCount == 0)
    }

    @Test func zeroRepRIRDoesNotCountAsPerformedWork() {
        let exercise = lift(sets: [(100, 0, 0, true)])
        let s = session(minutes: 20, [exercise])

        #expect(!s.hasLoggedRIR)
        #expect(s.hardSetCount == 0)
    }

    // MARK: - Waterfall

    @Test func volumeSharesSplitTheRepsPool() {
        // Bench 2000 (2×100×10), Row 1000 (1×100×10) → 2/3 and 1/3.
        let bench = lift("Bench Press", .chest, sets: [(100, 10, nil, true), (100, 10, nil, true)])
        let row = lift("Barbell Row", .back, sets: [(100, 10, nil, true)])
        let s = session(minutes: 30, [bench, row])
        let contrib = s.contributions()

        #expect(abs((contrib[bench.id]?.share ?? 0) - 2.0 / 3.0) < 0.001)
        #expect(abs((contrib[row.id]?.share ?? 0) - 1.0 / 3.0) < 0.001)
        #expect(contrib[bench.id]?.isDuration == false)
    }

    @Test func holdsFormTheirOwnSeparatePool() {
        // A reps lift and two holds: the holds split the hold-time
        // pool (90 / 30) independently of the weight-volume pool.
        let press = lift("Overhead Press", .shoulders, sets: [(100, 10, nil, true)])
        let plank = hold("Plank", seconds: [90])
        let hang = hold("Dead Hang", seconds: [30])
        let s = session(minutes: 25, [press, plank, hang])
        let contrib = s.contributions()

        // Reps lift owns 100% of the (single-exercise) volume pool.
        #expect(abs((contrib[press.id]?.share ?? 0) - 1.0) < 0.001)
        // Holds split 90:30 of the hold-time pool.
        #expect(abs((contrib[plank.id]?.share ?? 0) - 0.75) < 0.001)
        #expect(abs((contrib[hang.id]?.share ?? 0) - 0.25) < 0.001)
        #expect(contrib[plank.id]?.isDuration == true)
    }

    @Test func volumeSharesUseEffectiveLoadAndOmitIneligibleReps() {
        let assisted = lift(
            "Assisted Pull-Up",
            .back,
            sets: [(55, 10, nil, true)],
            loadMode: .assistanceSubtracted,
            bodyweightFraction: 1
        )
        let external = lift("Barbell Row", .back, sets: [(100, 10, nil, true)])
        let conditioning = lift(
            "Burpee",
            sets: [(100, 10, nil, true)],
            modality: .conditioning
        )
        let banded = lift(
            "Band Row",
            .back,
            sets: [(100, 10, nil, true)],
            loadMode: .nonComparable
        )
        let contrib = session(
            minutes: 20,
            [assisted, external, conditioning, banded],
            bodyweightAtStart: 155
        ).contributions()

        #expect(contrib[assisted.id]?.metric == 1_000)
        #expect(contrib[external.id]?.metric == 1_000)
        #expect(contrib[assisted.id]?.share == 0.5)
        #expect(contrib[external.id]?.share == 0.5)
        #expect(contrib[conditioning.id] == nil)
        #expect(contrib[banded.id] == nil)
    }

    @Test func conditioningAndMobilityDurationRemainTimedContributions() {
        let conditioning = hold("Loaded Carry", seconds: [90])
        conditioning.modality = .conditioning
        let mobility = hold("Codman Pendulum", seconds: [30])
        mobility.modality = .mobility
        let contrib = session(minutes: 10, [conditioning, mobility]).contributions()

        #expect(contrib[conditioning.id]?.metric == 90)
        #expect(contrib[conditioning.id]?.share == 0.75)
        #expect(contrib[conditioning.id]?.isDuration == true)
        #expect(contrib[mobility.id]?.metric == 30)
        #expect(contrib[mobility.id]?.share == 0.25)
        #expect(contrib[mobility.id]?.isDuration == true)
    }

    // MARK: - Adherence

    @Test func beatPlanWhenTopSetExceedsPlannedWeight() {
        let ex = lift(sets: [(105, 8, nil, true)], planWeight: 100, planReps: 8)
        let s = session(minutes: 20, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.weightDelta == 5)
        #expect(adherence?.repsDelta == 0)
        #expect(adherence?.beatPlan == true)
        #expect(adherence?.isOnPlan == false)
    }

    @Test func onPlanWhenTopSetMatches() {
        let ex = lift(sets: [(100, 8, nil, true)], planWeight: 100, planReps: 8)
        let s = session(minutes: 20, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.isOnPlan == true)
    }

    @Test func repDeltaWhenSameWeightFewerReps() {
        let ex = lift(sets: [(100, 6, nil, true)], planWeight: 100, planReps: 8)
        let s = session(minutes: 20, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.weightDelta == 0)
        #expect(adherence?.repsDelta == -2)
        #expect(adherence?.beatPlan == false)
    }

    @Test func assistedTopSetAndAdherenceUseInverseResistance() {
        let ex = lift(
            "Assisted Pull-Up",
            .back,
            sets: [
                (60, 8, nil, true),
                (40, 8, nil, true),
            ],
            planWeight: 60,
            planReps: 8,
            loadMode: .assistanceSubtracted,
            bodyweightFraction: 1
        )
        let s = session(minutes: 20, [ex])

        #expect(s.topSet(for: ex)?.weight == 40)
        // Body weight is unknown, but it is the same constant on both
        // sides: planned 60 assist → actual 40 assist is +20 resistance.
        #expect(s.adherence(for: ex)?.weightDelta == 20)
        #expect(s.adherence(for: ex)?.beatPlan == true)
    }

    @Test func nonComparableAdherenceUsesRepsInsteadOfEnteredLoad() {
        let ex = lift(
            "Band Row",
            .back,
            sets: [
                (2, 10, nil, true),
                (1, 12, nil, true),
            ],
            planWeight: 2,
            planReps: 10,
            loadMode: .nonComparable
        )
        let s = session(minutes: 20, [ex])

        #expect(s.topSet(for: ex)?.reps == 12)
        #expect(s.adherence(for: ex)?.weightDelta == 0)
        #expect(s.adherence(for: ex)?.repsDelta == 2)
    }

    @Test func adherenceNilWithoutAPlan() {
        let ex = lift(sets: [(100, 8, nil, true)])  // no plan snapshot
        let s = session(minutes: 20, [ex])
        #expect(s.adherence(for: ex) == nil)
    }

    @Test func holdAdherenceTracksDurationDelta() {
        let ex = hold("Plank", seconds: [75], planDuration: 60)
        let s = session(minutes: 10, [ex])
        let adherence = s.adherence(for: ex)
        #expect(adherence?.isDuration == true)
        #expect(adherence?.durationDelta == 15)
        #expect(adherence?.beatPlan == true)
    }

    @Test func loadedHoldAdherenceComparesLoadBeforeDuration() {
        func loadedHold(weight: Double, duration: TimeInterval) -> Exercise {
            let exercise = Exercise(
                name: "Loaded Hold Fixture",
                group: .core,
                plannedSets: 1,
                plannedReps: 0,
                plannedWeight: 50,
                trackingMode: .duration,
                modality: .isometricStrength,
                loadMode: .external,
                plannedDuration: 60
            )
            exercise.sets.forEach {
                $0.weight = weight
                $0.duration = duration
                $0.isCompleted = true
            }
            return exercise
        }

        let heavierShorter = loadedHold(weight: 55, duration: 30)
        let heavierAdherence = session(minutes: 10, [heavierShorter])
            .adherence(for: heavierShorter)
        #expect(heavierAdherence?.weightDelta == 5)
        #expect(heavierAdherence?.durationDelta == -30)
        #expect(heavierAdherence?.beatPlan == true)

        let sameLoadLonger = loadedHold(weight: 50, duration: 75)
        let longerAdherence = session(minutes: 10, [sameLoadLonger])
            .adherence(for: sameLoadLonger)
        #expect(longerAdherence?.weightDelta == 0)
        #expect(longerAdherence?.durationDelta == 15)
        #expect(longerAdherence?.beatPlan == true)

        let lighterLonger = loadedHold(weight: 45, duration: 120)
        let lighterAdherence = session(minutes: 10, [lighterLonger])
            .adherence(for: lighterLonger)
        #expect(lighterAdherence?.weightDelta == -5)
        #expect(lighterAdherence?.durationDelta == 60)
        #expect(lighterAdherence?.beatPlan == false)
        #expect(lighterAdherence?.isOnPlan == false)
    }
}

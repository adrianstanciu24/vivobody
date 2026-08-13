//
//  TrainingSignatureTests.swift
//  vivobodyTests
//
//  Guards the Insights lifetime-training emblem. The signature is a
//  pure reduction of all-time hard-set allocation plus archive cadence,
//  so the mapping is checked on a virtual clock: six petals always,
//  shares that sum to one, a lopsided archive surfacing its lead region,
//  stable lifetime allocation, the even-share guide, and honest empty
//  states.
//

import Foundation
import Testing
import VivoKit
@testable import vivobody

@MainActor
struct TrainingSignatureTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup, sets: Int = 3, rir: Int = 2) -> Exercise {
        let catalogInvolvement = Muscle.involvement(forExerciseNamed: name)
        let involvement = catalogInvolvement.isEmpty
            ? Muscle.Involvement(contributions: [
                .init(muscle: primaryMuscle(for: group), role: .primary),
            ])
            : catalogInvolvement
        let ex = Exercise(
            name: name,
            group: group,
            plannedSets: sets,
            plannedReps: 8,
            plannedWeight: 100,
            muscleInvolvement: involvement
        )
        ex.sets.forEach {
            $0.isCompleted = true
            $0.repsInReserve = rir
            $0.rirLogged = true
        }
        return ex
    }

    private func primaryMuscle(for group: MuscleGroup) -> Muscle {
        switch group {
        case .chest: return .pectoralisMajorSternocostal
        case .back: return .lats
        case .shoulders: return .deltoidAnterior
        case .legs: return .vasti
        case .arms: return .bicepsBrachii
        case .core: return .abs
        }
    }

    private func fullBody(at date: Date) -> WorkoutSession {
        session(at: date, [
            lift("Barbell Bench Press", .chest),
            lift("Barbell Bent-Over Row", .back),
            lift("Standing Barbell Overhead Press", .shoulders),
            lift("Barbell Back Squat", .legs),
            lift("Supinated Straight-Bar Cable Curl", .arms),
            lift("Stable Forearm Plank", .core),
        ])
    }

    // MARK: - Always six regions

    @Test func signatureCoversEverySixRegions() {
        let sig = [fullBody(at: day(100))].trainingSignature(now: day(100))
        #expect(sig.petals.count == 6)
        #expect(sig.petals.map(\.group) == MuscleGroup.allCases)
        #expect(sig.hasSignature)
        #expect(sig.hasVolume)
        #expect(sig.trainedGroupCount == 6)
        #expect(abs(sig.coverage - 1) < 1e-9)
    }

    // MARK: - Shares sum to one

    @Test func volumeSharesSumToOne() {
        let sig = [fullBody(at: day(100))].trainingSignature(now: day(100))
        let total = sig.petals.map(\.volumeShare).reduce(0, +)
        #expect(abs(total - 1.0) < 1e-9)
    }

    @Test func oneExercisePricesItsMuscleGroupOnlyOnceAtStrongestRole() {
        let exercise = Exercise(
            name: "Split Chest Fixture",
            group: .chest,
            plannedSets: 4,
            plannedReps: 8,
            plannedWeight: 100,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .pectoralisMajorSternocostal, role: .primary),
                .init(muscle: .pectoralisMajorClavicular, role: .secondary),
            ])
        )
        exercise.sets.forEach { $0.isCompleted = true }
        let workout = session(at: day(100), [exercise])
        let accumulator = AnalyticsAccumulator.replay([workout])

        #expect(accumulator.allTimeMuscleGroupVolume(now: day(100))[.chest] == 4)
        let signature = [workout].trainingSignature(now: day(100))
        #expect(signature.petals.first { $0.group == .chest }?.volumeShare == 1)
    }

    @Test func allTimeGroupPassHonorsCancellation() {
        let workout = session(
            at: day(100),
            [lift("Barbell Bench Press", .chest)]
        )
        let accumulator = AnalyticsAccumulator.replay([workout])

        #expect(
            accumulator.allTimeMuscleGroupVolume(
                now: day(100),
                isCancelled: { true }
            ).isEmpty
        )
    }

    // MARK: - A lopsided block surfaces its lead

    @Test func dominantRegionSurfaces() {
        let sessions = (0..<3).map { i in
            session(at: day(100 - Double(i) * 2), [lift("Barbell Back Squat", .legs)])
        }
        let sig = sessions.trainingSignature(now: day(100))

        #expect(sig.dominantGroup == .legs)
        let legs = sig.petals.first { $0.group == .legs }
        #expect((legs?.volumeShare ?? 0) > 0.5)
    }

    // MARK: - A fuller spread reads more balanced

    @Test func fullBodyReadsMoreBalancedThanSingleLift() {
        let mixed = [fullBody(at: day(100))].trainingSignature(now: day(100))
        let narrow = [session(at: day(100), [lift("Barbell Back Squat", .legs)])].trainingSignature(now: day(100))
        #expect(mixed.balance > narrow.balance)
    }

    @Test func balanceIsNormalisedAgainstAllSixRegions() {
        let sig = TrainingSignature(
            groupVolume: [.chest: 4, .back: 4],
            cadence: 0
        )
        let expected: Double = Foundation.log(2) / Foundation.log(6)

        #expect(sig.trainedGroupCount == 2)
        #expect(abs(sig.coverage - (2.0 / 6.0)) < 1e-9)
        #expect(abs(sig.balance - expected) < 1e-9)
        #expect(sig.dominantGroup == nil) // equal leaders are not chosen arbitrarily
        #expect(sig.identityLine == "No single lead · 2 regions")
    }

    @Test func equalAllSixCoverageReachesFullBalance() {
        let sig = TrainingSignature(
            groupVolume: Dictionary(
                uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 4) }
            ),
            cadence: 0
        )

        #expect(sig.trainedGroupCount == 6)
        #expect(abs(sig.coverage - 1) < 1e-9)
        #expect(abs(sig.balance - 1) < 1e-9)
        #expect(sig.dominantGroup == nil)
        #expect(sig.identityLine == "Evenly spread · all 6 regions")
    }

    // MARK: - All-time allocation

    @Test func lifetimeWidthDoesNotExpireWhenWeeklyVolumeIsZero() {
        let old = session(at: day(20), [lift("Barbell Bench Press", .chest)])
        let sig = [old].trainingSignature(now: day(100))

        #expect(sig.hasSignature)
        #expect(sig.hasVolume)
        #expect((sig.petals.first { $0.group == .chest }?.volumeShare ?? 0) > 0)
    }

    @Test func inactiveHistoryKeepsLifetimeIdentity() {
        let old = session(at: day(65), [lift("Barbell Bench Press", .chest)])
        let sig = [old].trainingSignature(now: day(100))

        #expect(sig.hasSignature)
        #expect(sig.hasVolume)
        #expect(sig.trainedGroupCount > 0)
        #expect((sig.petals.first { $0.group == .chest }?.volumeShare ?? 0) > 0)
    }

    @Test func oldAndRecentWorkBothContributeToLifetimeSplit() {
        let old = session(at: day(10), [lift("Barbell Bench Press", .chest)])
        let recent = session(at: day(100), [lift("Barbell Back Squat", .legs)])
        let sig = [old, recent].trainingSignature(now: day(100))

        #expect((sig.petals.first { $0.group == .chest }?.volumeShare ?? 0) > 0)
        #expect((sig.petals.first { $0.group == .legs }?.volumeShare ?? 0) > 0)
    }

    @Test func lifetimeAllocationDoesNotChangeAsClockAdvances() {
        let archive = [
            session(at: day(10), [lift("Barbell Bench Press", .chest)]),
            session(at: day(20), [lift("Barbell Back Squat", .legs)]),
        ]
        let first = archive.trainingSignature(now: day(30))
        let later = archive.trainingSignature(now: day(300))

        #expect(first.petals.map(\.volumeShare) == later.petals.map(\.volumeShare))
        #expect(first.balance == later.balance)
        #expect(first.coverage == later.coverage)
    }

    @Test func cadenceUsesTheFullArchiveSpan() {
        let archive = [
            session(at: day(0), [lift("Barbell Bench Press", .chest)]),
            session(at: day(100), [lift("Barbell Back Squat", .legs)]),
        ]
        let sig = archive.trainingSignature(now: day(100))

        #expect(abs(sig.cadence - (14.0 / 101.0)) < 1e-9)
    }

    @Test func firstWorkoutReadsAsOnePerWeekWithoutExtrapolation() {
        let sig = [session(at: day(100), [lift("Barbell Bench Press", .chest)])]
            .trainingSignature(now: day(100))

        #expect(sig.cadence == 1)
    }

    @Test func lifetimeCadenceReflectsInactiveTime() {
        let archive = [
            session(at: day(0), [lift("Barbell Bench Press", .chest)]),
            session(at: day(7), [lift("Barbell Back Squat", .legs)]),
        ]
        let early = archive.trainingSignature(now: day(7))
        let later = archive.trainingSignature(now: day(100))

        #expect(later.cadence < early.cadence)
    }

    @Test func futureWorkoutDoesNotEnterLifetimeCadence() {
        let future = session(at: day(110), [lift("Barbell Bench Press", .chest)])
        let sig = [future].trainingSignature(now: day(100))

        #expect(sig.cadence == 0)
    }

    @Test func timedStrengthCanShapeTheLifetimeSignature() {
        let plank = Exercise(
            name: "Plank",
            group: .core,
            plannedSets: 3,
            plannedReps: 0,
            plannedWeight: 0,
            muscleInvolvement: Muscle.Involvement(contributions: [
                .init(muscle: .abs, role: .primary),
            ]),
            trackingMode: .duration,
            modality: .isometricStrength,
            plannedDuration: 45
        )
        plank.sets.forEach { $0.isCompleted = true }
        let sig = [session(at: day(100), [plank])].trainingSignature(now: day(100))
        #expect(sig.hasSignature)
        #expect((sig.petals.first { $0.group == .core }?.volumeShare ?? 0) > 0)
    }

    // MARK: - Lifetime geometry

    @Test func equalShareGuideSitsBetweenMinorAndLeadRegions() {
        let minor = SignatureEmblemTuning.reachFraction(volumeShare: 0.07)
        let even = SignatureEmblemTuning.reachFraction(
            volumeShare: SignatureEmblemTuning.equalShare
        )
        let lead = SignatureEmblemTuning.reachFraction(volumeShare: 0.42)

        #expect(minor > 0.24)
        #expect(minor < even)
        #expect(even < lead)
    }

    @Test func zeroShareIsInvisibleAndTinyShareRemainsLegible() {
        #expect(
            SignatureEmblemTuning.petalOpacity(
                volumeShare: 0,
                isDominant: false
            ) == 0
        )
        #expect(
            SignatureEmblemTuning.petalOpacity(
                volumeShare: 0.01,
                isDominant: false
            ) > 0.8
        )
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNoSignature() {
        let sig = [WorkoutSession]().trainingSignature(now: day(100))
        #expect(!sig.hasSignature)
        #expect(!sig.hasVolume)
        #expect(sig.cadence == 0)
        #expect(sig.trainedGroupCount == 0)
        #expect(sig.coverage == 0)
        #expect(sig.petals.count == 6)
        #expect(sig.petals.allSatisfy { $0.volumeShare == 0 })
        #expect(sig.dominantGroup == nil)
        #expect(sig.balance == 0)
    }
}

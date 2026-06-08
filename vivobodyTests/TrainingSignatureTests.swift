//
//  TrainingSignatureTests.swift
//  vivobodyTests
//
//  Guards the Insights "Training DNA" emblem. The signature is a pure
//  fusion of the balance, momentum, and consistency models, so the
//  mapping is checked on a virtual clock: six petals always, shares
//  that sum to one, a lopsided block surfacing its lead region, a
//  fuller spread reading more balanced, effort tracking reps-in-
//  reserve, and an empty archive drawing nothing.
//

import Foundation
import Testing
@testable import vivobody

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
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: 8, plannedWeight: 100)
        ex.sets.forEach { $0.isCompleted = true; $0.repsInReserve = rir }
        return ex
    }

    private func fullBody(at date: Date) -> WorkoutSession {
        session(at: date, [
            lift("Bench Press", .chest),
            lift("Barbell Row", .back),
            lift("Overhead Press", .shoulders),
            lift("Back Squat", .legs),
            lift("Barbell Curl", .arms),
            lift("Plank", .core),
        ])
    }

    // MARK: - Always six regions

    @Test func signatureCoversEverySixRegions() {
        let sig = [fullBody(at: day(100))].trainingSignature(now: day(100))
        #expect(sig.petals.count == 6)
        #expect(sig.petals.map(\.group) == MuscleGroup.allCases)
        #expect(sig.hasSignature)
    }

    // MARK: - Shares sum to one

    @Test func volumeSharesSumToOne() {
        let sig = [fullBody(at: day(100))].trainingSignature(now: day(100))
        let total = sig.petals.map(\.volumeShare).reduce(0, +)
        #expect(abs(total - 1.0) < 1e-9)
    }

    // MARK: - A lopsided block surfaces its lead

    @Test func dominantRegionSurfaces() {
        let sessions = (0..<3).map { i in
            session(at: day(100 - Double(i) * 2), [lift("Squats", .legs)])
        }
        let sig = sessions.trainingSignature(now: day(100))

        #expect(sig.dominantGroup == .legs)
        let legs = sig.petals.first { $0.group == .legs }
        #expect((legs?.volumeShare ?? 0) > 0.5)
    }

    // MARK: - A fuller spread reads more balanced

    @Test func fullBodyReadsMoreBalancedThanSingleLift() {
        let mixed = [fullBody(at: day(100))].trainingSignature(now: day(100))
        let narrow = [session(at: day(100), [lift("Back Squat", .legs)])].trainingSignature(now: day(100))
        #expect(mixed.balance > narrow.balance)
    }

    // MARK: - Effort tracks reps-in-reserve

    @Test func intensityReflectsEffort() {
        let allOut = [session(at: day(100), [lift("Bench Press", .chest, rir: 0)])]
            .trainingSignature(now: day(100))
        #expect(abs(allOut.intensity - 1.0) < 1e-9)        // 0 in reserve → full intensity

        let easy = [session(at: day(100), [lift("Bench Press", .chest, rir: 5)])]
            .trainingSignature(now: day(100))
        #expect(abs(easy.intensity - 0.0) < 1e-9)          // 5 in reserve → none
    }

    @Test func intensityIsNeutralWithoutLoggedReps() {
        // A timed-hold-only day carries no reps-in-reserve.
        let plank = Exercise(
            name: "Plank",
            group: .core,
            plannedSets: 3,
            plannedReps: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            plannedDuration: 45
        )
        plank.sets.forEach { $0.isCompleted = true }
        let sig = [session(at: day(100), [plank])].trainingSignature(now: day(100))
        #expect(sig.hasSignature)
        #expect(abs(sig.intensity - 0.5) < 1e-9)
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNoSignature() {
        let sig = [WorkoutSession]().trainingSignature(now: day(100))
        #expect(!sig.hasSignature)
        #expect(sig.petals.count == 6)
        #expect(sig.petals.allSatisfy { $0.volumeShare == 0 && $0.development == 0 })
        #expect(sig.dominantGroup == nil)
        #expect(sig.balance == 0)
    }
}

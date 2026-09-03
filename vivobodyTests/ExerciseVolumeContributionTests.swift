//
//  ExerciseVolumeContributionTests.swift
//  vivobodyTests
//
//  Guards the per-exercise weekly hard-set contribution behind the
//  Exercise Detail "This week" card. All behaviour is date-, role-,
//  and RIR-driven through the shared SetStimulus currency, so it is
//  tested on a virtual clock with no simulator.
//
//  Covered:
//    • Role credit — primary 1.0, secondary 0.5, stabilizer absent.
//    • RIR discount — logged RIR beyond 2 discounts; unlogged stays
//      neutral.
//    • Window — exactly 7 days back counts; older and future-dated
//      sessions do not.
//    • Identity — only sessions matching the catalog item count.
//    • Gating — non-volume modalities and anatomy-less items return nil.
//    • Roles — a muscle removed from the current involvement keeps its
//      credit but renders roleless, sorted last.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseVolumeContributionTests {
    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date {
        Self.origin.addingTimeInterval(n * 86400)
    }

    // MARK: - Fixtures

    private let involvement = Muscle.Involvement(contributions: [
        .init(muscle: .pectoralisMajorSternocostal, role: .primary),
        .init(muscle: .triceps, role: .secondary),
        .init(muscle: .serratus, role: .stabilizer),
    ])

    private func item(
        catalogID: String? = "fixture-bench",
        involvement: Muscle.Involvement? = nil
    ) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            catalogID: catalogID,
            name: "Fixture Bench",
            group: .chest,
            defaultWeight: 135,
            muscleInvolvement: involvement ?? self.involvement
        )
    }

    private func session(
        at date: Date,
        sets: Int = 3,
        catalogID: String? = "fixture-bench",
        modality: ExerciseModality = .dynamicStrength,
        rir: Int = 0,
        rirLogged: Bool = false
    ) -> WorkoutSession {
        let exercise = Exercise(
            name: "Fixture Bench",
            catalogID: catalogID,
            group: .chest,
            plannedSets: sets,
            plannedReps: 8,
            plannedWeight: 135,
            muscleInvolvement: involvement,
            modality: modality
        )
        for set in exercise.orderedSets {
            set.isCompleted = true
            set.repsInReserve = rir
            set.rirLogged = rirLogged
        }
        let session = WorkoutSession(exercises: [exercise], startedAt: date)
        session.completedAt = date
        return session
    }

    private func share(
        _ muscle: Muscle,
        in contribution: ExerciseVolumeContribution?
    ) -> ExerciseVolumeContribution.MuscleShare? {
        contribution?.shares.first { $0.muscle == muscle }
    }

    // MARK: - Role credit

    @Test func rolesCreditPrimarySecondaryAndNotStabilizer() {
        let workout = session(at: day(-1))
        let catalogItem = item()
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [workout],
            item: catalogItem,
            now: day(0)
        )
        let pureContribution = ExerciseVolumeContribution.compute(
            accumulator: AnalyticsAccumulator.replay(
                AnalyticsSnapshot(sessions: [workout])
            ),
            historyKey: catalogItem.historyKey,
            currentRoles: catalogItem.muscleInvolvement.roles,
            now: day(0)
        )
        #expect(pureContribution == contribution)
        #expect(share(.pectoralisMajorSternocostal, in: contribution)?.sets == 3)
        #expect(share(.triceps, in: contribution)?.sets == 1.5)
        #expect(share(.serratus, in: contribution) == nil)
        #expect(contribution?.totalSets == 4.5)
    }

    @Test func sharesSortPrimaryFirstThenSetsDescending() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1))],
            item: item(),
            now: day(0)
        )
        #expect(contribution?.shares.map(\.muscle) == [
            .pectoralisMajorSternocostal, .triceps,
        ])
        #expect(contribution?.shares.first?.role == .primary)
    }

    // MARK: - RIR discount

    @Test func loggedRIRBeyondTwoDiscounts() {
        // RIR 4 → 0.8² = 0.64 per set; 3 sets → 1.92 primary credit.
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1), rir: 4, rirLogged: true)],
            item: item(),
            now: day(0)
        )
        #expect(abs((share(.pectoralisMajorSternocostal, in: contribution)?.sets ?? 0) - 1.92) < 0.0001)
    }

    @Test func unloggedRIRStaysNeutral() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1), rir: 5, rirLogged: false)],
            item: item(),
            now: day(0)
        )
        #expect(share(.pectoralisMajorSternocostal, in: contribution)?.sets == 3)
    }

    // MARK: - Window

    @Test func sessionExactlySevenDaysBackCounts() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-7))],
            item: item(),
            now: day(0)
        )
        #expect(share(.pectoralisMajorSternocostal, in: contribution)?.sets == 3)
    }

    @Test func sessionOlderThanTheWindowDoesNotCount() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-8))],
            item: item(),
            now: day(0)
        )
        #expect(contribution == nil)
    }

    @Test func futureDatedSessionDoesNotCount() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(1))],
            item: item(),
            now: day(0)
        )
        #expect(contribution == nil)
    }

    @Test func inWindowSessionsAccumulate() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1)), session(at: day(-3))],
            item: item(),
            now: day(0)
        )
        #expect(share(.pectoralisMajorSternocostal, in: contribution)?.sets == 6)
        #expect(share(.triceps, in: contribution)?.sets == 3)
    }

    @Test func indexedRawContributionRelabelsWithCurrentCatalogRoles() {
        let workouts = [
            session(at: day(-1)),
            session(at: day(-3)),
            session(at: day(-1), catalogID: "fixture-fly"),
        ]
        let trimmed = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorSternocostal, role: .primary),
        ])
        let catalogItem = item(involvement: trimmed)
        let accumulator = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: workouts)
        )
        let rawByKey = ExerciseVolumeContribution
            .rawContributionsByHistoryKey(
                accumulator: accumulator,
                now: day(0)
            )
        let indexed = ExerciseVolumeContribution.relabel(
            rawByKey[catalogItem.historyKey],
            currentRoles: catalogItem.muscleInvolvement.roles
        )
        let focused = ExerciseVolumeContribution.compute(
            sessions: workouts,
            item: catalogItem,
            now: day(0)
        )

        #expect(rawByKey.keys.count == 2)
        #expect(indexed == focused)
        #expect(share(.pectoralisMajorSternocostal, in: indexed)?.sets == 6)
        #expect(share(.triceps, in: indexed)?.role == nil)
    }

    // MARK: - Identity and gating

    @Test func unrelatedExerciseIsIgnored() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1), catalogID: "fixture-fly")],
            item: item(),
            now: day(0)
        )
        #expect(contribution == nil)
    }

    @Test func nonVolumeModalityEarnsNothing() {
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1), modality: .power)],
            item: item(),
            now: day(0)
        )
        #expect(contribution == nil)
    }

    @Test func anatomyLessItemRendersSharesWithoutRoles() {
        let bare = Muscle.Involvement(contributions: [])
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1))],
            item: item(involvement: bare),
            now: day(0)
        )
        // The exercise's own snapshot still credits its muscles; the
        // item simply renders those shares without role qualifiers.
        #expect(share(.pectoralisMajorSternocostal, in: contribution)?.role == nil)
    }

    @Test func muscleRemovedFromCurrentInvolvementRendersRolelessAndLast() {
        // History credits triceps, but the current item lists only the
        // primary — the removed muscle keeps its share without a role.
        let trimmed = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorSternocostal, role: .primary),
        ])
        let contribution = ExerciseVolumeContribution.compute(
            sessions: [session(at: day(-1))],
            item: item(involvement: trimmed),
            now: day(0)
        )
        #expect(share(.triceps, in: contribution)?.role == nil)
        #expect(contribution?.shares.last?.muscle == .triceps)
    }
}

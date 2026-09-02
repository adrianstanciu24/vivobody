//
//  LivePersonalRecordTests.swift
//  vivobodyTests
//
//  Guards tap-time live personal-record classification across performance,
//  load, history-availability, identity, and in-session comparison boundaries.
//

import Foundation
import Testing
@testable import vivobody

struct LivePersonalRecordTests {
    private func candidate(
        name: String = "Bench Press",
        catalogID: String? = "bench-press",
        modality: ExerciseModality = .dynamicStrength,
        trackingMode: TrackingMode = .reps,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        bodyweight: Double = 0,
        weight: Double = 100,
        repetitions: Int = 8,
        duration: TimeInterval = 0,
        prior: [StrengthPerformance] = []
    ) -> LivePersonalRecordCandidate {
        LivePersonalRecordCandidate(
            exerciseName: name,
            catalogItemID: nil,
            catalogID: catalogID,
            performanceSignature: ExercisePerformanceSignature(
                modality: modality,
                trackingMode: trackingMode,
                loadMode: loadMode,
                bodyweightFraction: bodyweightFraction
            ),
            loadProfile: ExerciseLoadProfile(
                mode: loadMode,
                bodyweightFraction: bodyweightFraction
            ),
            bodyweight: bodyweight,
            loggedWeight: weight,
            repetitions: repetitions,
            duration: duration,
            priorInSessionPerformances: prior
        )
    }

    @Test func heavierLoadAndEqualLoadRepetitionsReportTheAdvancingAxis() {
        let heavier = candidate(prior: [.dynamic(effectiveLoad: 95, reps: 20)])
        let moreReps = candidate(
            repetitions: 9,
            prior: [.dynamic(effectiveLoad: 100, reps: 8)]
        )

        #expect(LivePersonalRecord.evaluate(heavier, history: [:])?.advancement == .load)
        #expect(LivePersonalRecord.evaluate(moreReps, history: [:])?.advancement == .repetitions)
    }

    @Test func loadedAndUnloadedHoldsPreserveTheirComparisonSemantics() {
        let heavierHold = candidate(
            modality: .isometricStrength,
            trackingMode: .duration,
            weight: 110,
            repetitions: 0,
            duration: 30,
            prior: [.isometric(effectiveLoad: 100, duration: 90)]
        )
        let longerLoadedHold = candidate(
            modality: .isometricStrength,
            trackingMode: .duration,
            weight: 100,
            repetitions: 0,
            duration: 45,
            prior: [.isometric(effectiveLoad: 100, duration: 30)]
        )
        let longerUnloadedHold = candidate(
            name: "Plank",
            catalogID: "plank",
            modality: .isometricStrength,
            trackingMode: .duration,
            loadMode: .nonComparable,
            weight: 0,
            repetitions: 0,
            duration: 60,
            prior: [.isometric(duration: 45)]
        )

        #expect(LivePersonalRecord.evaluate(heavierHold, history: [:])?.advancement == .load)
        #expect(LivePersonalRecord.evaluate(longerLoadedHold, history: [:])?.advancement == .duration)
        #expect(LivePersonalRecord.evaluate(longerUnloadedHold, history: [:])?.advancement == .duration)
    }

    @Test func bodyweightAndAssistanceUseEffectiveResistance() {
        let weightedPullUp = candidate(
            name: "Pull-Up",
            catalogID: "pull-up",
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1,
            bodyweight: 180,
            weight: 25,
            prior: [.dynamic(effectiveLoad: 200, reps: 8)]
        )
        let assistedPullUp = candidate(
            name: "Assisted Pull-Up",
            catalogID: "assisted-pull-up",
            loadMode: .assistanceSubtracted,
            bodyweightFraction: 1,
            bodyweight: 180,
            weight: 40,
            prior: [.dynamic(effectiveLoad: 130, reps: 12)]
        )

        #expect(weightedPullUp.performance == .dynamic(effectiveLoad: 205, reps: 8))
        #expect(assistedPullUp.performance == .dynamic(effectiveLoad: 140, reps: 8))
        #expect(LivePersonalRecord.evaluate(weightedPullUp, history: [:])?.advancement == .load)
        #expect(LivePersonalRecord.evaluate(assistedPullUp, history: [:])?.advancement == .load)
    }

    @Test func bestPriorInSessionSetPreventsAFalseRecord() {
        let candidate = candidate(
            prior: [
                .dynamic(effectiveLoad: 90, reps: 20),
                .dynamic(effectiveLoad: 105, reps: 5),
            ]
        )

        #expect(LivePersonalRecord.evaluate(candidate, history: [:]) == nil)
    }

    @Test func unsupportedAndInvalidPerformancesNeverCreateRecords() {
        let unsupportedPower = candidate(
            modality: .power,
            loadMode: .nonComparable
        )
        let zeroLoad = candidate(weight: 0)
        let zeroReps = candidate(repetitions: 0)
        let zeroDuration = candidate(
            modality: .isometricStrength,
            trackingMode: .duration,
            loadMode: .nonComparable,
            weight: 0,
            repetitions: 0,
            duration: 0
        )

        #expect(LivePersonalRecord.evaluate(unsupportedPower, history: [:]) == nil)
        #expect(LivePersonalRecord.evaluate(zeroLoad, history: [:]) == nil)
        #expect(LivePersonalRecord.evaluate(zeroReps, history: [:]) == nil)
        #expect(LivePersonalRecord.evaluate(zeroDuration, history: [:]) == nil)
    }

    @Test func unavailableHistoryIsUnknownWhileKnownEmptyAllowsAFirstRecord() {
        let candidate = candidate()

        #expect(LivePersonalRecord.evaluate(candidate, history: nil) == nil)
        #expect(LivePersonalRecord.evaluate(candidate, history: [:])?.advancement == .load)
    }

    @Test @MainActor func archivedLookupUsesTheFrozenExerciseIdentity() {
        let archivedExercise = Exercise(
            name: "Bench Press",
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        archivedExercise.sets.append(
            WorkoutSet(
                weight: 120,
                reps: 5,
                isCompleted: true,
                sortOrder: 0
            )
        )
        let archivedSession = WorkoutSession(exercises: [archivedExercise])
        archivedSession.completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let history = AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: [archivedSession])
        ).exerciseHistoryByExercise()

        let matching = candidate(weight: 115, repetitions: 20)
        let renamedIdentity = candidate(
            name: "Incline Press",
            catalogID: "incline-press",
            weight: 115,
            repetitions: 20
        )

        #expect(LivePersonalRecord.evaluate(matching, history: history) == nil)
        #expect(LivePersonalRecord.evaluate(renamedIdentity, history: history)?.advancement == .load)
    }

    @Test func activePresentationPreservesExistingValueUnitAndDetailCopy() throws {
        let loadCandidate = candidate(weight: 100)
        let loadRecord = try #require(
            LivePersonalRecord.evaluate(loadCandidate, history: [:])
        )
        #expect(
            ActivePersonalRecordPresentation.payload(
                for: loadRecord,
                candidate: loadCandidate,
                unit: .lb
            ) == ActiveSetPersonalRecordPayload(
                value: "100",
                unit: "lb",
                detail: "Bench Press · New max"
            )
        )

        let repCandidate = candidate(
            repetitions: 9,
            prior: [.dynamic(effectiveLoad: 100, reps: 8)]
        )
        let repRecord = try #require(
            LivePersonalRecord.evaluate(repCandidate, history: [:])
        )
        #expect(
            ActivePersonalRecordPresentation.payload(
                for: repRecord,
                candidate: repCandidate,
                unit: .lb
            ) == ActiveSetPersonalRecordPayload(
                value: "9",
                unit: "reps",
                detail: "Bench Press · at 100 lb"
            )
        )

        let holdCandidate = candidate(
            name: "Plank",
            catalogID: "plank",
            modality: .isometricStrength,
            trackingMode: .duration,
            loadMode: .nonComparable,
            weight: 0,
            repetitions: 0,
            duration: 60
        )
        let holdRecord = try #require(
            LivePersonalRecord.evaluate(holdCandidate, history: [:])
        )
        #expect(
            ActivePersonalRecordPresentation.payload(
                for: holdRecord,
                candidate: holdCandidate,
                unit: .kg
            ) == ActiveSetPersonalRecordPayload(
                value: "1:00",
                unit: nil,
                detail: "Plank · Longest hold"
            )
        )
    }
}

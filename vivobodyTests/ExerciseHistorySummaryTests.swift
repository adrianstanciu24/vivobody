//
//  ExerciseHistorySummaryTests.swift
//  vivobodyTests
//
//  Guards the single-pass exercise-history index shared by workout
//  startup and live PR detection: best-vs-latest behavior, prescription
//  capture, distinct-session counts, and cache readiness.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct ExerciseHistorySummaryTests {
    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(
        daysAfterBase: Double,
        sets: [(Double, Int)],
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external
    ) -> WorkoutSession {
        let exercise = Exercise(
            name: "Bench Press",
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0,
            modality: modality,
            loadMode: loadMode
        )
        for (index, value) in sets.enumerated() {
            exercise.sets.append(
                WorkoutSet(
                    weight: value.0,
                    reps: value.1,
                    isCompleted: true,
                    sortOrder: index
                )
            )
        }
        let date = baseDate.addingTimeInterval(daysAfterBase * 86_400)
        let session = WorkoutSession(exercises: [exercise], startedAt: date)
        session.completedAt = date
        return session
    }

    private func summaries(
        _ sessions: [WorkoutSession]
    ) -> [String: ExerciseHistorySummary] {
        AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: sessions)
        ).exerciseHistoryByExercise()
    }

    @Test func summaryKeepsBestAndLatestIndependently() throws {
        let oldest = session(daysAfterBase: 0, sets: [(100, 8)])
        let best = session(daysAfterBase: 1, sets: [(120, 5)])
        let latest = session(
            daysAfterBase: 2,
            sets: [(115, 10), (110, 12), (105, 15)]
        )

        let history = summaries([latest, oldest, best])
        let key = try #require(latest.orderedExercises.first?.historyKey)
        let summary = try #require(history[key])

        #expect(summary.currentAllTimeBest == .dynamic(effectiveLoad: 120, reps: 5))
        #expect(summary.latestPerformanceDate == latest.startedAt)
        #expect(summary.mostRecentInstance.date == latest.startedAt)
        #expect(summary.sessionCount == 3)
        #expect(summary.mostRecentInstance.setPrescription.count == 3)
        #expect(summary.mostRecentInstance.setPrescription[0].weight == 115)
        #expect(summary.mostRecentInstance.setPrescription[2].reps == 15)
    }

    @Test func sessionCountDeduplicatesRepeatedExerciseRows() throws {
        let workout = session(daysAfterBase: 0, sets: [(100, 8)])
        let duplicate = Exercise(
            name: "Bench Press",
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        duplicate.sets.append(
            WorkoutSet(
                weight: 105,
                reps: 8,
                isCompleted: true,
                sortOrder: 0
            )
        )
        workout.exercises.append(duplicate)

        let key = duplicate.historyKey
        let summary = try #require(summaries([workout])[key])
        #expect(summary.sessionCount == 1)
        #expect(summary.currentAllTimeBest == .dynamic(effectiveLoad: 105, reps: 8))
    }

    @Test func nonRecordWorkStillRetainsLatestPrescription() throws {
        let conditioning = session(
            daysAfterBase: 0,
            sets: [(40, 20), (45, 15)],
            modality: .conditioning,
            loadMode: .nonComparable
        )
        let key = try #require(conditioning.orderedExercises.first?.historyKey)
        let summary = try #require(summaries([conditioning])[key])

        #expect(summary.currentAllTimeBest == nil)
        #expect(summary.sessionCount == 1)
        #expect(summary.mostRecentInstance.completedSetPrescription.count == 2)
    }

    @Test func freshExerciseUsesCachedPrescriptionAndResetsCompletion() throws {
        let latest = session(
            daysAfterBase: 0,
            sets: [(150, 6), (145, 8)]
        )
        let key = try #require(latest.orderedExercises.first?.historyKey)
        let summary = try #require(summaries([latest])[key])
        let item = ExerciseCatalogItem(
            catalogID: "bench-press",
            name: "Bench Press",
            group: .chest,
            defaultWeight: 135,
            defaultReps: 8
        )

        let exercise = Exercise.fresh(
            from: item,
            history: summary,
            sortOrder: 4
        )

        #expect(exercise.sortOrder == 4)
        #expect(exercise.orderedSets.count == 2)
        #expect(exercise.orderedSets[0].weight == 150)
        #expect(exercise.orderedSets[1].reps == 8)
        #expect(exercise.orderedSets.allSatisfy { !$0.isCompleted })
        #expect(exercise.orderedSets[0].plannedWeight == 150)
    }

    @Test func emptyArchiveBecomesKnownEmptyAfterFallbackPrime() throws {
        let schema = Schema(SchemaV5.models, version: SchemaV5.versionIdentifier)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let analytics = SessionAnalytics()

        #expect(!analytics.hasExerciseHistorySummaries)
        let history = try #require(
            analytics.resolvedExerciseHistory(in: ModelContext(container))
        )
        #expect(history.isEmpty)
        #expect(analytics.hasExerciseHistorySummaries)
    }
}

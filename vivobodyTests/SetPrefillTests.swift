//
//  SetPrefillTests.swift
//  vivobodyTests
//
//  Guards the two "start from what you actually did" behaviors:
//  in-session carry-forward (completing a set mirrors its logged
//  values onto the remaining same-plan pending sets, leaving pyramid
//  prescriptions intact) and template-start prefill (spawning a
//  workout from a template seeds each set's working values from the
//  most recent archived performance while the planned snapshots keep
//  the template's prescription).
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

// MARK: - In-session carry-forward

@MainActor
struct SetCarryForwardTests {

    private func uniformExercise(weight: Double = 135, reps: Int = 8) -> Exercise {
        Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 3,
            plannedReps: reps,
            plannedWeight: weight
        )
    }

    @Test func completedValuesCarryToRemainingUniformSets() {
        let ex = uniformExercise()
        let session = WorkoutSession(exercises: [ex])

        session.updateActiveWeight(for: ex, weight: 150)
        session.updateActiveReps(for: ex, reps: 6)
        session.completeActiveSet(for: ex)

        let sets = ex.orderedSets
        #expect(sets[0].isCompleted)
        #expect(sets[1].weight == 150 && sets[1].reps == 6)
        #expect(sets[2].weight == 150 && sets[2].reps == 6)
        // Planned snapshots keep the original prescription.
        #expect(sets[1].plannedWeight == 135 && sets[1].plannedReps == 8)
    }

    @Test func carryForwardChainsAcrossSets() {
        let ex = uniformExercise()
        let session = WorkoutSession(exercises: [ex])

        session.updateActiveWeight(for: ex, weight: 150)
        session.completeActiveSet(for: ex)
        session.updateActiveWeight(for: ex, weight: 155)
        session.completeActiveSet(for: ex)

        #expect(ex.orderedSets[2].weight == 155)
    }

    @Test func pyramidPrescriptionsSurviveCompletion() {
        let ex = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 0,
            plannedReps: 10,
            plannedWeight: 100
        )
        let plan: [(weight: Double, reps: Int)] = [(100, 10), (120, 8), (140, 6)]
        for (i, step) in plan.enumerated() {
            ex.sets.append(
                WorkoutSet(
                    weight: step.weight,
                    reps: step.reps,
                    sortOrder: i,
                    plannedWeight: step.weight,
                    plannedReps: step.reps
                )
            )
        }
        let session = WorkoutSession(exercises: [ex])

        session.updateActiveWeight(for: ex, weight: 105)
        session.completeActiveSet(for: ex)

        let sets = ex.orderedSets
        #expect(sets[0].weight == 105)
        #expect(sets[1].weight == 120 && sets[1].reps == 8)
        #expect(sets[2].weight == 140 && sets[2].reps == 6)
    }

    @Test func durationCarriesForwardOnTimedExercises() {
        let ex = Exercise(
            name: "Plank",
            group: .core,
            plannedSets: 3,
            plannedWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength,
            plannedDuration: 45
        )
        let session = WorkoutSession(exercises: [ex])

        session.updateActiveDuration(for: ex, duration: 70)
        session.completeActiveSet(for: ex)

        #expect(ex.orderedSets[1].duration == 70)
        #expect(ex.orderedSets[2].duration == 70)
    }

    @Test func completedSetsAreNeverOverwritten() {
        let ex = uniformExercise()
        let session = WorkoutSession(exercises: [ex])

        session.completeActiveSet(for: ex)
        let firstWeight = ex.orderedSets[0].weight
        session.updateActiveWeight(for: ex, weight: 200)
        session.completeActiveSet(for: ex)

        #expect(ex.orderedSets[0].weight == firstWeight)
        #expect(ex.orderedSets[2].weight == 200)
    }
}

// MARK: - Template-start prefill

@MainActor
struct TemplatePrefillTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models, version: SchemaV3.versionIdentifier)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func templateExercise(catalogID: String? = "bench-press") -> TemplateExercise {
        TemplateExercise(
            name: "Bench Press",
            catalogID: catalogID,
            group: .chest,
            plannedSets: 3,
            plannedReps: 8,
            plannedWeight: 135
        )
    }

    /// Archive one session containing a single logged exercise built
    /// by `configure`, completed `daysAgo` days before `now`.
    private func archiveSession(
        in context: ModelContext,
        daysAgo: Double,
        configure: (Exercise) -> Void
    ) throws {
        let ex = Exercise(
            name: "Bench Press",
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        configure(ex)
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let session = WorkoutSession(exercises: [ex], startedAt: date)
        session.completedAt = date
        context.insert(session)
        try context.save()
    }

    private func appendCompletedSets(
        _ values: [(weight: Double, reps: Int)],
        to ex: Exercise
    ) {
        for (i, v) in values.enumerated() {
            ex.sets.append(
                WorkoutSet(weight: v.weight, reps: v.reps, isCompleted: true, sortOrder: i)
            )
        }
    }

    @Test func spawnedSetsMirrorLastLoggedValues() throws {
        let context = try makeContext()
        try archiveSession(in: context, daysAgo: 2) {
            appendCompletedSets([(155, 6), (155, 6), (150, 5)], to: $0)
        }

        let spawned = Exercise.fromTemplate(templateExercise(), history: context)

        let sets = spawned.orderedSets
        #expect(sets.count == 3)
        #expect(sets[0].weight == 155 && sets[0].reps == 6)
        #expect(sets[2].weight == 150 && sets[2].reps == 5)
        // The template's prescription survives in the planned snapshots.
        #expect(sets.allSatisfy { $0.plannedWeight == 135 && $0.plannedReps == 8 })
        #expect(sets.allSatisfy { !$0.isCompleted })
    }

    @Test func mostRecentSessionWins() throws {
        let context = try makeContext()
        try archiveSession(in: context, daysAgo: 9) {
            appendCompletedSets([(140, 8), (140, 8), (140, 8)], to: $0)
        }
        try archiveSession(in: context, daysAgo: 2) {
            appendCompletedSets([(160, 5), (160, 5), (160, 5)], to: $0)
        }

        let spawned = Exercise.fromTemplate(templateExercise(), history: context)
        #expect(spawned.orderedSets.allSatisfy { $0.weight == 160 })
    }

    @Test func shorterHistoryRepeatsItsLastSet() throws {
        let context = try makeContext()
        try archiveSession(in: context, daysAgo: 1) {
            appendCompletedSets([(145, 8), (150, 6)], to: $0)
        }

        let spawned = Exercise.fromTemplate(templateExercise(), history: context)

        let sets = spawned.orderedSets
        #expect(sets[0].weight == 145)
        #expect(sets[1].weight == 150)
        #expect(sets[2].weight == 150 && sets[2].reps == 6)
    }

    @Test func noHistoryKeepsTemplateValues() throws {
        let context = try makeContext()
        let spawned = Exercise.fromTemplate(templateExercise(), history: context)
        #expect(spawned.orderedSets.allSatisfy { $0.weight == 135 && $0.reps == 8 })
    }

    @Test func uncompletedHistorySetsDoNotSeed() throws {
        let context = try makeContext()
        try archiveSession(in: context, daysAgo: 1) { ex in
            ex.sets.append(WorkoutSet(weight: 155, reps: 6, isCompleted: false, sortOrder: 0))
        }

        let spawned = Exercise.fromTemplate(templateExercise(), history: context)
        #expect(spawned.orderedSets.allSatisfy { $0.weight == 135 })
    }

    @Test func mismatchedSignatureKeepsTemplateValues() throws {
        let context = try makeContext()
        // Same catalog identity, but logged as a timed hold — its
        // values live under different semantics and must not seed a
        // reps prescription.
        let ex = Exercise(
            name: "Bench Press",
            catalogID: "bench-press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength
        )
        ex.sets.append(WorkoutSet(weight: 0, reps: 0, duration: 60, isCompleted: true, sortOrder: 0))
        let session = WorkoutSession(exercises: [ex], startedAt: now)
        session.completedAt = now
        context.insert(session)
        try context.save()

        let spawned = Exercise.fromTemplate(templateExercise(), history: context)
        #expect(spawned.orderedSets.allSatisfy { $0.weight == 135 && $0.reps == 8 })
    }

    @Test func perSetTemplatesSpawnExactlyAsWritten() throws {
        let context = try makeContext()
        try archiveSession(in: context, daysAgo: 1) {
            appendCompletedSets([(200, 3), (200, 3), (200, 3)], to: $0)
        }

        let te = templateExercise()
        te.sets = [
            TemplateSet(weight: 100, reps: 10, sortOrder: 0),
            TemplateSet(weight: 120, reps: 8, sortOrder: 1),
            TemplateSet(weight: 140, reps: 6, sortOrder: 2),
        ]

        let spawned = Exercise.fromTemplate(te, history: context)

        let sets = spawned.orderedSets
        #expect(sets[0].weight == 100 && sets[0].reps == 10)
        #expect(sets[1].weight == 120 && sets[1].reps == 8)
        #expect(sets[2].weight == 140 && sets[2].reps == 6)
    }
}

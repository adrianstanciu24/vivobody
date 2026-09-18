//
//  TemplateLoadResolutionTests.swift
//  vivobodyTests
//
//  Guards missing-versus-zero loads, fixed intent and load-policy draft fidelity.
//

import Foundation
import Testing
@testable import vivobody

struct TemplateLoadResolutionTests {
    @Test func missingAndIntentionalZeroAreDifferent() {
        let missing = TemplateLoadResolution.resolve(policy: .lastWorkout, setCount: 3,
                                                     startingWeight: nil, lastWeights: [], lastDate: nil)
        let zero = TemplateLoadResolution.resolve(policy: .lastWorkout, setCount: 3,
                                                  startingWeight: 0, lastWeights: [], lastDate: nil)
        #expect(missing.weights == nil)
        #expect(zero.weights == [0, 0, 0])
        #expect(missing.summary(loadMode: .external, unit: .lb) == "Set starting load")
        #expect(zero.summary(loadMode: .assistanceSubtracted, unit: .lb).contains("Unassisted"))
    }

    @Test func rememberedLoadsMapToTheTemplatesSetCount() {
        let resolved = TemplateLoadResolution.resolve(policy: .lastWorkout, setCount: 4,
                                                      startingWeight: 40, lastWeights: [60, 55], lastDate: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(resolved.weights == [60, 55, 55, 55])
        #expect(resolved.source == "Last used")
        #expect(resolved.date != nil)
    }

    @Test func fixedLoadRetainsTheSavedValue() {
        let resolved = TemplateLoadResolution.resolve(policy: .fixed, setCount: 2,
                                                      startingWeight: 40, lastWeights: [60, 55, 50], lastDate: Date())
        #expect(resolved.weights == [40, 40])
        #expect(resolved.date == nil)
        #expect(resolved.source == "Fixed")
    }

    @MainActor @Test func newCatalogDraftHasNoInventedLoadAndRoundTripsPolicy() throws {
        let record = try #require(CatalogData.record(forCatalogID: "barbell-bench-press"))
        let item = ExerciseCatalogItem(record: record, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        var draft = ExerciseDraft(from: item)
        #expect(draft.loadPolicy == .lastWorkout)
        #expect(!draft.hasStartingLoad)
        #expect(draft.plannedWeight == 0)
        draft.hasStartingLoad = true
        draft.plannedWeight = 155
        let template = draft.makeTemplateExercise(sortOrder: 0)
        let reopened = ExerciseDraft(from: template)
        #expect(reopened.hasStartingLoad)
        #expect(reopened.loadPolicy == .lastWorkout)
        #expect(reopened.plannedWeight == 155)
        draft.switchToPerSet()
        #expect(draft.makeTemplateExercise(sortOrder: 0).loadPolicy == .fixed)
    }

    @MainActor @Test func rememberedDurationKeepsTheTemplateTarget() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let logged = Exercise(name: "Loaded hold", catalogID: "fixture-hold", group: .core,
                              plannedSets: 0, plannedWeight: 0, trackingMode: .duration, modality: .isometricStrength)
        logged.sets = [WorkoutSet(weight: 90, reps: 0, duration: 70, isCompleted: true)]
        let session = WorkoutSession(exercises: [logged], startedAt: date)
        session.completedAt = date
        let history = AnalyticsAccumulator.history(AnalyticsSnapshot(sessions: [session])).exerciseHistoryByExercise()
        let template = TemplateExercise(name: "Loaded hold", catalogID: "fixture-hold", group: .core,
                                        plannedSets: 2, plannedWeight: 60, trackingMode: .duration, modality: .isometricStrength, plannedDuration: 45)
        template.loadPolicy = .lastWorkout
        let spawned = Exercise.fromTemplate(template, history: history[template.historyKey])
        #expect(spawned.sets.count == 2)
        #expect(spawned.sets.allSatisfy { $0.weight == 90 && $0.duration == 45 && $0.plannedDuration == 45 && $0.plannedWeight == 90 })
    }

    @MainActor @Test func rememberedAssistanceRetainsLoggedSettingSemantics() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let logged = Exercise(name: "Assisted pull", catalogID: "fixture-assist", group: .back,
                              plannedSets: 0, plannedWeight: 0, loadMode: .assistanceSubtracted, bodyweightFraction: 1)
        logged.sets = [WorkoutSet(weight: 40, reps: 6, isCompleted: true)]
        let session = WorkoutSession(exercises: [logged], startedAt: date)
        session.completedAt = date
        let history = AnalyticsAccumulator.history(AnalyticsSnapshot(sessions: [session])).exerciseHistoryByExercise()
        let template = TemplateExercise(name: "Assisted pull", catalogID: "fixture-assist", group: .back,
                                        plannedSets: 3, plannedReps: 8, plannedWeight: 60, loadMode: .assistanceSubtracted, bodyweightFraction: 1)
        template.loadPolicy = .lastWorkout
        let spawned = Exercise.fromTemplate(template, history: history[template.historyKey])
        #expect(spawned.loadMode == .assistanceSubtracted)
        #expect(spawned.sets.allSatisfy { $0.weight == 40 && $0.reps == 8 })
        #expect(template.resolveLoad(history: history[template.historyKey]).summary(loadMode: .assistanceSubtracted, unit: .lb).contains("assist"))
    }
}

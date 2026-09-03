//
//  TodayUpNextPresentationTests.swift
//  vivobodyTests
//
//  Deterministic characterization of Today's immutable Up Next formatting,
//  preview limits, load semantics, schedule copy, and PR proximity gate.
//

import Foundation
import Testing
@testable import vivobody

struct TodayUpNextPresentationTests {
    typealias Source = TodayUpNextPresentation.Source
    typealias ExerciseSource = TodayUpNextPresentation.Source.Exercise
    typealias SetPlan = TodayUpNextPresentation.Source.Exercise.SetPlan

    @Test func presentationIsSendable() {
        func requireSendable(_: (some Sendable).Type) {}
        requireSendable(TodayUpNextPresentation.self)
        requireSendable(TodayUpNextPresentation.Source.self)
    }

    @MainActor
    @Test func realTemplateAdapterPreservesOrderIdentityNormalizationAndKgSemantics() {
        let row = TemplateExercise(
            name: "Cable Row",
            catalogItemID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
            group: .back,
            plannedSets: 99,
            plannedReps: 5,
            plannedWeight: 1,
            classification: ExerciseClassification(
                equipment: .cable,
                mechanic: .compound,
                trainingRole: .pull,
                pattern: .pull,
                direction: .horizontal,
                planes: [.transverse],
                laterality: .bilateral
            ),
            loadMode: .external,
            sortOrder: 0
        )
        row.sets.append(TemplateSet(weight: 120, reps: 6, sortOrder: 2))
        row.sets.append(TemplateSet(weight: 100, reps: 10, sortOrder: 0))
        row.sets.append(TemplateSet(weight: 110, reps: 8, sortOrder: 1))

        let unloaded = TemplateExercise(
            name: "Push-Up",
            catalogItemID: UUID(uuidString: "11111111-2222-3333-4444-555555555555"),
            group: .chest,
            plannedSets: 99,
            plannedReps: 12,
            plannedWeight: 0,
            classification: ExerciseClassification(
                equipment: .bodyweight,
                mechanic: .compound,
                trainingRole: .push,
                pattern: .push,
                direction: .horizontal,
                planes: [.transverse],
                laterality: .bilateral
            ),
            loadMode: .nonComparable,
            sortOrder: 1
        )
        // Simulate malformed legacy resistance. The adapter must apply the
        // exercise capability instead of presenting these stored values.
        unloaded.plannedWeight = 88
        unloaded.sets.append(TemplateSet(weight: 99, reps: 12, sortOrder: 1))
        unloaded.sets.append(TemplateSet(weight: 77, reps: 12, sortOrder: 0))

        let template = WorkoutTemplate(
            name: "Pull and Push",
            exercises: [unloaded, row]
        )
        let source = Source(
            template: template,
            daysUntil: 1,
            otherScheduledCount: 1,
            shouldEaseOff: false,
            outlook: StrengthOutlookBoard(stats: [])
        )

        #expect(source.exercises.map(\.name) == ["Cable Row", "Push-Up"])
        #expect(source.exercises[0].sets.map(\.reps) == [10, 8, 6])
        #expect(source.exercises[0].sets.map(\.weight) == [100, 110, 120])
        let rowHistoryKey = [
            "catalog:AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "performance:dynamicLoadAndReps",
            "modality=dynamicStrength",
            "tracking=reps",
            "load=external",
            "bodyweightBps=0",
            "resistance=tracked",
        ].joined(separator: ":")
        let unloadedHistoryKey = [
            "catalog:11111111-2222-3333-4444-555555555555",
            "performance:unrankedReps",
            "modality=dynamicStrength",
            "tracking=reps",
            "load=nonComparable",
            "bodyweightBps=0",
            "resistance=untracked",
        ].joined(separator: ":")
        #expect(source.exercises[0].historyKey == rowHistoryKey)
        #expect(source.exercises[1].historyKey == unloadedHistoryKey)
        #expect(source.exercises[1].plannedWeight == 0)
        #expect(source.exercises[1].sets.map(\.weight) == [0, 0])

        let presentation = TodayUpNextPresentation(
            source: source,
            unit: .kg,
            defaultRestSeconds: SettingsDefaults.defaultRestSeconds
        )
        #expect(presentation.scheduleText == "Tomorrow")
        #expect(presentation.metadata == "2 exercises  ·  ~15 min  ·  +1 more")
        #expect(presentation.muscleSummary == "Back · 3 sets   Chest · 2 sets")
        let separator = Locale.current.decimalSeparator ?? "."
        #expect(presentation.exerciseRows[0].scheme == .init(
            count: "3 × 6–10",
            load: "45\(separator)4–54\(separator)4 kg",
            loadUnit: nil
        ))
        #expect(presentation.exerciseRows[1].scheme == .init(
            count: "2 × 12",
            load: nil,
            loadUnit: nil
        ))
    }

    @Test func previewUsesFiveRowsNormallyAndThreeForAccessibility() {
        let exercises = (1 ... 6).map { index in
            exercise(name: "Exercise \(index)", plannedSets: 1)
        }
        let presentation = makePresentation(
            otherScheduledCount: 2,
            exercises: exercises
        )

        let standard = presentation.preview(accessibilityLayout: false)
        #expect(standard.rows.map(\.name) == [
            "Exercise 1", "Exercise 2", "Exercise 3", "Exercise 4", "Exercise 5",
        ])
        #expect(standard.remainingCount == 1)

        let accessibility = presentation.preview(accessibilityLayout: true)
        #expect(accessibility.rows.map(\.name) == ["Exercise 1", "Exercise 2", "Exercise 3"])
        #expect(accessibility.remainingCount == 3)
        #expect(presentation.metadata == "6 exercises  ·  ~15 min  ·  +2 more")
    }

    @Test func durationEstimateUsesFiveMinuteGrainAndDefaultRestFallback() {
        let exercises = [exercise(plannedSets: 3)]

        let fallback = makePresentation(exercises: exercises, defaultRestSeconds: 0)
        #expect(fallback.durationEstimate == "~10 min")
        #expect(fallback.metadata == "1 exercise  ·  ~10 min")

        let shorterRest = makePresentation(exercises: exercises, defaultRestSeconds: 60)
        #expect(shorterRest.durationEstimate == "~5 min")

        let noSets = makePresentation(exercises: [exercise(plannedSets: 0)])
        #expect(noSets.durationEstimate == nil)
        #expect(noSets.metadata == "1 exercise")
    }

    @Test func muscleSummaryKeepsFirstAppearanceOrderAndEffectiveSetCounts() {
        let presentation = makePresentation(exercises: [
            exercise(name: "Bench", groupName: "Chest", plannedSets: 2),
            exercise(
                name: "Row",
                groupName: "Back",
                plannedSets: 99,
                sets: [set(), set(), set()]
            ),
            exercise(name: "Fly", groupName: "Chest", plannedSets: 1),
        ])

        #expect(presentation.muscleSummary == "Chest · 3 sets   Back · 3 sets")
    }

    @Test func repsSchemesPreserveUniformAndPerSetRanges() {
        let presentation = makePresentation(exercises: [
            exercise(
                name: "Bench Press",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 135
            ),
            exercise(
                name: "Incline Press",
                sets: [
                    set(reps: 8, weight: 100),
                    set(reps: 10, weight: 110),
                    set(reps: 12, weight: 120),
                ]
            ),
        ])

        #expect(presentation.exerciseRows[0].scheme == .init(
            count: "3 × 8",
            load: "135 lb",
            loadUnit: nil
        ))
        #expect(presentation.exerciseRows[0].accessibilityLabel == "Bench Press, 3 × 8 135 lb")
        #expect(presentation.exerciseRows[1].scheme == .init(
            count: "3 × 8–12",
            load: "100–120 lb",
            loadUnit: nil
        ))
    }

    @Test func durationSchemeLeadsWithTimeAndRetainsModalityAndLoadMeaning() {
        let presentation = makePresentation(exercises: [
            exercise(
                name: "Band Hold",
                trackingMode: .duration,
                durationLabel: "hold",
                loadMode: .nonComparable,
                sets: [
                    set(duration: 30, weight: 20),
                    set(duration: 45, weight: 25),
                ]
            ),
        ])

        let row = presentation.exerciseRows[0]
        #expect(row.scheme == .init(
            count: "2 ×",
            load: "0:30–0:45",
            loadUnit: "hold · 20–25 lb resistance"
        ))
        #expect(row.accessibilityLabel == "Band Hold, 2 × 0:30–0:45 hold · 20–25 lb resistance")
    }

    @Test func loadWordingDistinguishesExternalBodyweightAssistanceAndResistance() {
        let presentation = makePresentation(exercises: [
            exercise(name: "External", plannedWeight: 135),
            exercise(name: "Bodyweight", loadMode: .bodyweightAdded, plannedWeight: 0),
            exercise(name: "Assisted", loadMode: .assistanceSubtracted, plannedWeight: 40),
            exercise(name: "Band", loadMode: .nonComparable, plannedWeight: 20),
        ])

        #expect(presentation.exerciseRows.map(\.scheme.load) == [
            "135 lb", "BW", "40 lb assist", "20 lb resistance",
        ])
    }

    @Test func scheduleAndLoadGuidanceCopyCoverEveryBranch() {
        #expect(makePresentation(daysUntil: 0).scheduleText == "Today")
        #expect(makePresentation(daysUntil: 1).scheduleText == "Tomorrow")
        #expect(makePresentation(daysUntil: 4).scheduleText == "in 4 days")

        let guidance = makePresentation(shouldEaseOff: true).loadGuidance
        #expect(guidance?.text == "High load, keep this session lighter")
        #expect(guidance?.accessibilityLabel == "High training load, keep this session lighter")
        #expect(makePresentation(shouldEaseOff: false).loadGuidance == nil)
    }

    @Test func prProximityRequiresExactIdentityNonFreshResultAndWholePoundGap() {
        let bench = exercise(name: "Bench Press", historyKey: "bundled:bench")
        let matching = Source.NearestPR(
            historyKey: "bundled:bench",
            exerciseName: "Bench Press",
            currentE1RM: 200,
            bestE1RM: 204,
            isFresh: false
        )
        #expect(makePresentation(exercises: [bench], nearestPR: matching).prProximityText ==
            "4 lb from a Bench Press PR")

        let wrongIdentity = Source.NearestPR(
            historyKey: "name:bench press",
            exerciseName: "Bench Press",
            currentE1RM: 200,
            bestE1RM: 204,
            isFresh: false
        )
        #expect(makePresentation(exercises: [bench], nearestPR: wrongIdentity).prProximityText == nil)

        let fresh = Source.NearestPR(
            historyKey: "bundled:bench",
            exerciseName: "Bench Press",
            currentE1RM: 200,
            bestE1RM: 204,
            isFresh: true
        )
        #expect(makePresentation(exercises: [bench], nearestPR: fresh).prProximityText == nil)

        let subPoundGap = Source.NearestPR(
            historyKey: "bundled:bench",
            exerciseName: "Bench Press",
            currentE1RM: 203.5,
            bestE1RM: 204,
            isFresh: false
        )
        #expect(makePresentation(exercises: [bench], nearestPR: subPoundGap).prProximityText == nil)
    }

    @Test func prProximityUsesAnForVowelLedExerciseNames() {
        let press = exercise(name: "Overhead Press", historyKey: "bundled:overhead")
        let nearestPR = Source.NearestPR(
            historyKey: "bundled:overhead",
            exerciseName: "Overhead Press",
            currentE1RM: 100,
            bestE1RM: 105,
            isFresh: false
        )

        #expect(makePresentation(exercises: [press], nearestPR: nearestPR).prProximityText ==
            "5 lb from an Overhead Press PR")
    }

    private func makePresentation(
        daysUntil: Int = 0,
        otherScheduledCount: Int = 0,
        shouldEaseOff: Bool = false,
        exercises: [ExerciseSource]? = nil,
        nearestPR: Source.NearestPR? = nil,
        defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds
    ) -> TodayUpNextPresentation {
        TodayUpNextPresentation(
            source: Source(
                templateName: "Push",
                daysUntil: daysUntil,
                otherScheduledCount: otherScheduledCount,
                shouldEaseOff: shouldEaseOff,
                exercises: exercises ?? [exercise()],
                nearestPR: nearestPR
            ),
            unit: .lb,
            defaultRestSeconds: defaultRestSeconds
        )
    }

    private func exercise(
        name: String = "Bench Press",
        groupName: String = "Chest",
        historyKey: String = "bundled:bench",
        trackingMode: TrackingMode = .reps,
        durationLabel: String = "time",
        loadMode: ExerciseLoadMode = .external,
        plannedSets: Int = 3,
        plannedReps: Int = 8,
        plannedDuration: TimeInterval = 0,
        plannedWeight: Double = 0,
        sets: [SetPlan] = []
    ) -> ExerciseSource {
        ExerciseSource(
            id: UUID(),
            name: name,
            groupName: groupName,
            historyKey: historyKey,
            trackingModeRaw: trackingMode.rawValue,
            durationLabel: durationLabel,
            loadModeRaw: loadMode.rawValue,
            plannedSets: plannedSets,
            plannedReps: plannedReps,
            plannedDuration: plannedDuration,
            plannedWeight: plannedWeight,
            sets: sets
        )
    }

    private func set(
        reps: Int = 8,
        duration: TimeInterval = 0,
        weight: Double = 0
    ) -> SetPlan {
        SetPlan(reps: reps, duration: duration, weight: weight)
    }
}

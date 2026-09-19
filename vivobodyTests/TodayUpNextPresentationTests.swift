//
//  TodayUpNextPresentationTests.swift
//  vivobodyTests
//
//  Deterministic characterization of Today's immutable Up Next formatting,
//  preview limits, last-time reference, schedule copy, and PR proximity gate.
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
        #expect(presentation.exerciseRows.map(\.scheme) == ["3 × 6–10", "2 × 12"])
        #expect(presentation.lastTime == .init(
            title: "First time with this workout",
            columns: [],
            accessibilityLabel: "First time with this workout"
        ))
    }

    @MainActor
    @Test func realSessionAdapterSnapshotsSharedReceiptTotals() {
        let bench = TemplateExercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 3,
            plannedReps: 8,
            plannedWeight: 100,
            loadMode: .external,
            sortOrder: 0
        )
        let template = WorkoutTemplate(name: "Push", exercises: [bench])
        template.lastUsedAt = Date(timeIntervalSince1970: 1_000_000)

        let logged = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 3,
            plannedReps: 8,
            plannedWeight: 100,
            sortOrder: 0
        )
        logged.sets.forEach { $0.isCompleted = true }
        let session = WorkoutSession(exercises: [logged], restDuration: 90, startedAt: .now)
        session.completedAt = .now

        let source = Source(
            template: template,
            daysUntil: 0,
            otherScheduledCount: 0,
            shouldEaseOff: false,
            outlook: StrengthOutlookBoard(stats: []),
            lastSession: session,
            unit: .lb
        )
        #expect(source.lastUsedAt == template.lastUsedAt)
        #expect(source.lastSession?.totalSets == 3)
        #expect(source.lastSession?.totalReps == 24)
        #expect(source.lastSession?.receipt.kind == .volume(.complete))
        #expect(source.lastSession?.receipt.value == "2,400")

        let presentation = TodayUpNextPresentation(
            source: source,
            unit: .lb,
            defaultRestSeconds: SettingsDefaults.defaultRestSeconds
        )
        #expect(presentation.lastTime.title == "Last time  ·  Today")
        #expect(presentation.lastTime.columns == [
            .init(value: "3", label: "Sets", accessibilityLabel: "3 sets"),
            .init(value: "24", label: "Reps", accessibilityLabel: "24 reps"),
            .init(value: "2,400", unit: "lb", label: "Volume", accessibilityLabel: "2400 pounds of volume"),
        ])
        #expect(presentation.lastTime.accessibilityLabel ==
            "Last time, Today, 3 sets, 24 reps, 2400 pounds of volume")
    }

    @Test func previewUsesFourRowsNormallyAndThreeForAccessibility() {
        let exercises = (1 ... 6).map { index in
            exercise(name: "Exercise \(index)", plannedSets: 1)
        }
        let presentation = makePresentation(
            otherScheduledCount: 2,
            exercises: exercises
        )

        let standard = presentation.preview(accessibilityLayout: false)
        #expect(standard.rows.map(\.name) == [
            "Exercise 1", "Exercise 2", "Exercise 3", "Exercise 4",
        ])
        #expect(standard.remainingCount == 2)

        let accessibility = presentation.preview(accessibilityLayout: true)
        #expect(accessibility.rows.map(\.name) == ["Exercise 1", "Exercise 2", "Exercise 3"])
        #expect(accessibility.remainingCount == 3)
        #expect(presentation.metadata == "6 exercises  ·  ~15 min  ·  +2 more")
    }

    @Test func previewShowsASingleRemainingExerciseInsteadOfAMoreRow() {
        let five = makePresentation(exercises: (1 ... 5).map { exercise(name: "Exercise \($0)") })
        #expect(five.preview(accessibilityLayout: false).rows.count == 5)
        #expect(five.preview(accessibilityLayout: false).remainingCount == 0)
        #expect(five.preview(accessibilityLayout: true).rows.count == 3)
        #expect(five.preview(accessibilityLayout: true).remainingCount == 2)

        let four = makePresentation(exercises: (1 ... 4).map { exercise(name: "Exercise \($0)") })
        #expect(four.preview(accessibilityLayout: true).rows.count == 4)
        #expect(four.preview(accessibilityLayout: true).remainingCount == 0)
    }

    @Test func lastTimeSummarizesTheMatchingSessionAndFallsBackToLastUsed() throws {
        let now = Date(timeIntervalSince1970: 1_757_800_000)
        let calendar = Calendar(identifier: .gregorian)
        let fourDaysAgo = try #require(calendar.date(byAdding: .day, value: -4, to: now))
        let receipt = WorkoutReceiptMetric(
            kind: .volume(.complete),
            value: "3,240",
            qualifier: nil,
            unit: "kg",
            label: "Volume",
            accessibilityLabel: "3240 kilograms of volume"
        )
        let session = Source.LastSession(date: fourDaysAgo, totalSets: 15, totalReps: 142, receipt: receipt)

        let withSession = makePresentation(lastSession: session, now: now, calendar: calendar)
        #expect(withSession.lastTime.title == "Last time  ·  4 days ago")
        #expect(withSession.lastTime.columns == [
            .init(value: "15", label: "Sets", accessibilityLabel: "15 sets"),
            .init(value: "142", label: "Reps", accessibilityLabel: "142 reps"),
            .init(value: "3,240", unit: "kg", label: "Volume", accessibilityLabel: "3240 kilograms of volume"),
        ])
        #expect(withSession.lastTime.accessibilityLabel ==
            "Last time, 4 days ago, 15 sets, 142 reps, 3240 kilograms of volume")

        let partial = Source.LastSession(
            date: fourDaysAgo,
            totalSets: 6,
            totalReps: 0,
            receipt: WorkoutReceiptMetric(
                kind: .volume(.partial),
                value: "900",
                qualifier: "+",
                unit: "lb",
                label: "Known volume · total unavailable",
                accessibilityLabel: "900 pounds of known volume; total unavailable"
            )
        )
        #expect(makePresentation(lastSession: partial, now: now, calendar: calendar).lastTime.columns == [
            .init(value: "6", label: "Sets", accessibilityLabel: "6 sets"),
            .init(
                value: "900+",
                unit: "lb",
                label: "Known volume",
                accessibilityLabel: "900 pounds of known volume; total unavailable"
            ),
        ])

        let repsOnly = Source.LastSession(
            date: fourDaysAgo,
            totalSets: 3,
            totalReps: 36,
            receipt: WorkoutReceiptMetric(
                kind: .reps, value: "36", qualifier: nil, unit: nil, label: "Reps", accessibilityLabel: "36 reps"
            )
        )
        #expect(makePresentation(lastSession: repsOnly, now: now, calendar: calendar).lastTime.columns == [
            .init(value: "3", label: "Sets", accessibilityLabel: "3 sets"),
            .init(value: "36", label: "Reps", accessibilityLabel: "36 reps"),
        ])

        let lastUsed = makePresentation(lastUsedAt: fourDaysAgo, now: now, calendar: calendar).lastTime
        #expect(lastUsed == .init(
            title: "Last done  ·  4 days ago",
            columns: [],
            accessibilityLabel: "Last done, 4 days ago"
        ))
    }

    @Test func relativeDayTextCoversTodayYesterdayDayCountsAndDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 9)))
        func text(daysAgo: Int) -> String {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            return TodayUpNextPresentation.relativeDayText(date, now: now, calendar: calendar)
        }

        #expect(text(daysAgo: 0) == "Today")
        #expect(text(daysAgo: 1) == "Yesterday")
        #expect(text(daysAgo: 6) == "6 days ago")
        #expect(text(daysAgo: 7).contains("11"))
        #expect(text(daysAgo: 7).contains("2026") == false)
        #expect(text(daysAgo: 300).contains("2025"))
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

        #expect(presentation.exerciseRows[0].scheme == "3 × 8")
        #expect(presentation.exerciseRows[0].accessibilityLabel == "Bench Press, 3 × 8, Chest")
        #expect(presentation.exerciseRows[1].scheme == "3 × 8–12")
    }

    @Test func durationSchemeLeadsWithTimeAndRetainsModalityLabel() {
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
            exercise(
                name: "Plank",
                trackingMode: .duration,
                durationLabel: "hold",
                plannedSets: 3,
                plannedDuration: 60
            ),
        ])

        #expect(presentation.exerciseRows.map(\.scheme) == ["2 × 0:30–0:45 hold", "3 × 1:00 hold"])
        #expect(presentation.exerciseRows[0].accessibilityLabel == "Band Hold, 2 × 0:30–0:45 hold, Chest")
    }

    @Test func rowsOmitLoadsRegardlessOfLoadMode() {
        let presentation = makePresentation(exercises: [
            exercise(name: "External", plannedWeight: 135),
            exercise(name: "Bodyweight", loadMode: .bodyweightAdded, plannedWeight: 0),
            exercise(name: "Assisted", loadMode: .assistanceSubtracted, plannedWeight: 40),
            exercise(name: "Band", loadMode: .nonComparable, plannedWeight: 20),
        ])

        #expect(presentation.exerciseRows.map(\.scheme) == Array(repeating: "3 × 8", count: 4))
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
        lastUsedAt: Date? = nil,
        lastSession: Source.LastSession? = nil,
        unit: WeightUnit = .lb,
        defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayUpNextPresentation {
        TodayUpNextPresentation(
            source: Source(
                templateName: "Push",
                daysUntil: daysUntil,
                otherScheduledCount: otherScheduledCount,
                shouldEaseOff: shouldEaseOff,
                exercises: exercises ?? [exercise()],
                nearestPR: nearestPR,
                lastUsedAt: lastUsedAt,
                lastSession: lastSession
            ),
            unit: unit,
            defaultRestSeconds: defaultRestSeconds,
            now: now,
            calendar: calendar
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

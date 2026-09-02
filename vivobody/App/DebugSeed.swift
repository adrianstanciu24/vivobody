//
//  DebugSeed.swift
//  vivobody
//
//  Debug-only seed and UI-test support isolated from @main and Release builds.
//

import Foundation
import SwiftData
import VivoKit

#if DEBUG
    /// Launch-argument helpers that seed UI-test states and choose a capture tab.
    enum UITestSupport {
        static func requestedTab() -> AppTab? {
            guard let index = CommandLine.arguments.firstIndex(of: "--verify-tab"),
                  CommandLine.arguments.indices.contains(index + 1)
            else { return nil }
            return AppTab(rawValue: CommandLine.arguments[index + 1])
        }

        static func resetIfRequested(in context: ModelContext) {
            guard CommandLine.arguments.contains("--ui-test-reset") else { return }
            // The onboarding fixture reverses the normal tab-shell gate so its
            // one-time cover can use the same deterministic reset path.
            let shouldShowOnboarding = CommandLine.arguments.contains("--ui-test-onboarding")
            UserDefaults.standard.set(!shouldShowOnboarding, forKey: SettingsKey.onboardingCompleted)
            deleteAll(WorkoutSession.self, in: context)
            deleteAll(WorkoutTemplate.self, in: context)
            deleteAll(BodyWeightEntry.self, in: context)
            // Persist workout deletion before clearing its catalog dependencies.
            try? context.saveOrRollback()
            deleteAll(ExerciseCatalogItem.self, in: context)
            ExerciseCatalogItem.clearBundledCatalogDeletions()
            let sharedDefaults = UserDefaults(suiteName: WidgetShared.appGroup)
            sharedDefaults?.removeObject(forKey: WidgetShared.startWorkoutRequestKey)
            sharedDefaults?.removeObject(forKey: WidgetShared.completeSetRequestKey)
            sharedDefaults?.removeObject(forKey: WidgetShared.startTemplateWorkoutRequestKey)
            try? context.saveOrRollback()
        }

        static func seedIfRequested(in context: ModelContext) {
            seedExerciseSubstitutionIfRequested(in: context)
            seedActiveAssistanceIfRequested(in: context)
            CompletionRestorationSeed.prepareIfRequested(in: context)
            if CommandLine.arguments.contains("--ui-test-active-partial") {
                seedActivePartial(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-active-bodyweight") {
                seedActiveBodyweight(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-active-bodyweight-duration") {
                seedActiveBodyweightDuration(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-active-band")
                || CommandLine.arguments.contains("--ui-test-active-no-load")
                || CommandLine.arguments.contains("--ui-test-active-ab-wheel")
            {
                seedActiveLoadPresentation(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-superset") {
                seedActiveSuperset(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-superset-history") {
                seedSupersetHistory(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-superset-power") {
                seedActiveSupersetPower(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-single-exercise-history") {
                seedSingleExerciseHistory(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-insights-empty-instruments") {
                seedInsightsEmptyInstruments(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-insights-showcase") {
                InsightsShowcaseSeed.seed(in: context)
            }
            if CommandLine.arguments.contains("--ui-test-scheduled-template") {
                seedScheduledTemplate(in: context)
            }
            // AppRoot consumes this widget mailbox through the real IncomingActionParser handoff.
            if CommandLine.arguments.contains("--ui-test-widget-start-request") {
                UserDefaults(suiteName: WidgetShared.appGroup)?.set(
                    Date().timeIntervalSince1970,
                    forKey: WidgetShared.startWorkoutRequestKey
                )
            }
        }

        private static func seedActivePartial(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: 2,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            if let first = exercise.orderedSets.first { first.isCompleted = true }
            let session = WorkoutSession(exercises: [exercise], restDuration: 90)
            // Let the semantic harness inspect the receipt without a coordinate-based horizontal swipe.
            if CommandLine.arguments.contains("--ui-test-receipt-summary") { session.activeExerciseIndex = 1 }
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Focused visual-verification fixture for the active bodyweight
        /// instrument. The set stores zero added load while the exercise's
        /// snapshotted load profile supplies the bodyweight semantics.
        private static func seedActiveBodyweight(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = debugCatalogExercise(
                named: "Pull-Up",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 0,
                sortOrder: 0
            )
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                bodyweightAtStart: 180
            )
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Duration counterpart to the reps fixture above, used to verify
        /// that holds retain time as the hero while bodyweight and added
        /// load remain explicit beneath it.
        private static func seedActiveBodyweightDuration(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = Exercise(
                name: "Weighted Hang Fixture",
                group: .arms,
                plannedSets: 3,
                plannedReps: 0,
                plannedWeight: 0,
                trackingMode: .duration,
                modality: .isometricStrength,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1,
                plannedDuration: 30,
                sortOrder: 0
            )
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                bodyweightAtStart: 180
            )
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Active fixtures for non-comparable resistance and unloaded bodyweight UI.
        private static func seedActiveLoadPresentation(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let isAbWheel = CommandLine.arguments.contains("--ui-test-active-ab-wheel")
            let isNoLoad = isAbWheel || CommandLine.arguments.contains("--ui-test-active-no-load")
            let exercise = debugCatalogExercise(
                named: isAbWheel
                    ? "Kneeling Ab-Wheel Rollout"
                    : isNoLoad ? "Bodyweight Forward Lunge" : "Standing Band Fly",
                plannedSets: 3,
                plannedReps: isNoLoad ? 12 : 15,
                plannedWeight: 0,
                sortOrder: 0
            )
            if isNoLoad {
                // Simulate a stale draft to prove interpretation and normalization.
                exercise.plannedWeight = 45
                for set in exercise.sets {
                    set.weight = 45
                    set.plannedWeight = 45
                }
            }
            let session = WorkoutSession(exercises: [exercise], restDuration: 90)
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Active workout with the first two exercises linked as a
        /// superset (plus one straight-sets exercise after), for verifying
        /// the card ribbon, the merged page dots, the partner hand-off,
        /// and the round-aware rest label.
        private static func seedActiveSuperset(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let bench = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            let row = debugCatalogExercise(
                named: "Barbell Bent-Over Row",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 115,
                sortOrder: 1
            )
            let pairID = UUID()
            bench.supersetID = pairID
            row.supersetID = pairID

            let curl = debugCatalogExercise(
                named: "Supinated Straight-Bar Cable Curl",
                plannedSets: 3,
                plannedReps: 10,
                plannedWeight: 65,
                sortOrder: 2
            )
            let session = WorkoutSession(
                exercises: [bench, row, curl],
                restDuration: 90
            )
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// Active superset pairing a strength exercise with a power one —
        /// the partner logs reps but no RIR, so its card verifies that an
        /// omitted capability leaves no empty control slot.
        private static func seedActiveSupersetPower(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt == nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let pressAround = debugCatalogExercise(
                named: "Flat Dumbbell Fly",
                plannedSets: 3,
                plannedReps: 12,
                plannedWeight: 30 * WeightUnit.lbPerKg,
                sortOrder: 0
            )
            let clapPushUp = debugCatalogExercise(
                named: "Barbell Push Press",
                plannedSets: 3,
                plannedReps: 10,
                plannedWeight: 25 * WeightUnit.lbPerKg,
                sortOrder: 1
            )
            let pairID = UUID()
            pressAround.supersetID = pairID
            clapPushUp.supersetID = pairID

            let session = WorkoutSession(
                exercises: [pressAround, clapPushUp],
                restDuration: 90
            )
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// One archived session with a linked pair + one straight exercise,
        /// for verifying superset marks on the History detail ledger.
        private static func seedSupersetHistory(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let bench = debugCatalogExercise(
                named: "Barbell Bench Press",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 135,
                sortOrder: 0
            )
            let row = debugCatalogExercise(
                named: "Barbell Bent-Over Row",
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 115,
                sortOrder: 1
            )
            let pairID = UUID()
            bench.supersetID = pairID
            row.supersetID = pairID

            let curl = debugCatalogExercise(
                named: "Supinated Straight-Bar Cable Curl",
                plannedSets: 3,
                plannedReps: 10,
                plannedWeight: 65,
                sortOrder: 2
            )
            for exercise in [bench, row, curl] {
                for set in exercise.sets {
                    set.isCompleted = true
                }
            }

            let completedAt = Date().addingTimeInterval(-15 * 60)
            let session = WorkoutSession(
                exercises: [bench, row, curl],
                restDuration: 90,
                startedAt: completedAt.addingTimeInterval(-35 * 60)
            )
            session.completedAt = completedAt
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// One archived point for verifying the Exercise Detail chart's
        /// intentional pre-trend state. The catalog ID keeps the fixture
        /// tied to the bundled row even if its display name later changes.
        private static func seedSingleExerciseHistory(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = debugCatalogExercise(
                named: "Flat Dumbbell Fly",
                plannedSets: 1,
                plannedReps: 12,
                plannedWeight: 65 * WeightUnit.lbPerKg,
                sortOrder: 0
            )
            exercise.sets.first?.isCompleted = true

            let completedAt = Date().addingTimeInterval(-15 * 60)
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                startedAt: completedAt.addingTimeInterval(-35 * 60)
            )
            session.completedAt = completedAt
            context.insert(session)
            try? context.saveOrRollback()
        }

        /// One archived power workout for the Insights screen's
        /// per-instrument empty states. Consistency has a factual calendar
        /// mark, while strength-only signals remain deliberately unqualified.
        private static func seedInsightsEmptyInstruments(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            ))) ?? []
            guard existing.isEmpty else { return }

            let exercise = Exercise(
                name: "Box Jump",
                group: .legs,
                plannedSets: 1,
                plannedReps: 5,
                plannedWeight: 0,
                trackingMode: .reps,
                modality: .power,
                loadMode: .nonComparable,
                sortOrder: 0
            )
            exercise.sets.first?.isCompleted = true

            let completedAt = Date().addingTimeInterval(-15 * 60)
            let session = WorkoutSession(
                exercises: [exercise],
                restDuration: 90,
                startedAt: completedAt.addingTimeInterval(-25 * 60)
            )
            session.completedAt = completedAt
            context.insert(session)
            try? context.saveOrRollback()
        }

        private static func seedScheduledTemplate(in context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
            guard existing.isEmpty else { return }

            let template = WorkoutTemplate(
                name: "Scheduled Test",
                exercises: [
                    debugCatalogTemplateExercise(
                        named: "Barbell Bench Press",
                        plannedSets: 2,
                        plannedReps: 8,
                        plannedWeight: 135,
                        sortOrder: 0
                    )
                ]
            )
            template.scheduledWeekdays = [Calendar.current.component(.weekday, from: Date())]
            context.insert(template)
            try? context.saveOrRollback()
        }

        private static func deleteAll<T: PersistentModel>(_ model: T.Type, in context: ModelContext) {
            let descriptor = FetchDescriptor<T>()
            let models = (try? context.fetch(descriptor)) ?? []
            for model in models {
                context.delete(model)
            }
        }
    }

    /// Synthetic history seeders for manual debugging and visual QA.
    /// Each is driven by a launch argument and is idempotent — bails
    /// if the store already has data.
    enum HistorySeeder {
        static func seed(into context: ModelContext) {
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            )
            let existing = (try? context.fetch(descriptor)) ?? []
            guard existing.isEmpty else { return }

            let now = Date()
            let calendar = Calendar.current

            // Mix of muscle group combinations and date offsets so the
            // redesigned History screen exercises every layout branch:
            // today (rich), yesterday, this week, last week, older month.
            let plans: [(daysAgo: Int, hoursOffset: Int, groups: [MuscleGroup])] = [
                (0, -1, [.chest, .back, .shoulders, .legs]),
                (0, -2, [.chest, .back, .shoulders, .legs]),
                (0, -3, [.chest, .back, .shoulders, .legs]),
                (1, 0, [.arms, .core]),
                (2, 0, [.chest, .shoulders]),
                (3, 0, [.legs]),
                (5, 0, [.back, .arms]),
                (8, 0, [.chest, .back, .legs]),
                (14, 0, [.shoulders, .arms]),
                (28, 0, [.legs, .core]),
            ]

            for (i, plan) in plans.enumerated() {
                guard
                    let day = calendar.date(byAdding: .day, value: -plan.daysAgo, to: now),
                    let started = calendar.date(byAdding: .hour, value: plan.hoursOffset, to: day)
                else { continue }

                // Older sessions are lighter, recent ones heavier — plan
                // index 0 is the most recent, so the bonus grows as the
                // index shrinks. (Coupling weight to `i` directly would
                // invert progression and read as detraining.)
                let overloadStep = Double(plans.count - 1 - i) * 2.5

                let exercises: [Exercise] = plan.groups.enumerated().map { idx, group in
                    let template = templateExercise(for: group, variant: i)
                    let exercise = debugCatalogExercise(
                        named: template.name,
                        plannedSets: 3,
                        plannedReps: 8,
                        plannedWeight: template.weight + overloadStep,
                        sortOrder: idx
                    )
                    for set in exercise.sets {
                        set.isCompleted = true
                    }
                    return exercise
                }

                let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: started)
                session.completedAt = started.addingTimeInterval(40 * 60 + Double.random(in: 0 ... 600))
                context.insert(session)
            }
            try? context.saveOrRollback()
        }

        /// A deliberately lopsided ~10-week training history engineered so
        /// every render channel lights up at once on a different body
        /// region — the fastest way to eyeball the full colour palette.
        /// Drive it with `--seed-showcase`.
        ///
        ///   • Quads / glute max — heavy, progressive squats right up to a
        ///     few days ago ⇒ a deep, vivid orange (well developed).
        ///   • Glute med / TFL — recent hip-abduction work ⇒ visibly
        ///     distinct primary/secondary lateral-hip development.
        ///   • Chest / front delts — a progressive press block ⇒ developed
        ///     orange.
        ///   • Calves — a lighter raise block ⇒ a moderate orange.
        ///   • Biceps / triceps — the SAME load for fourteen sessions ⇒
        ///     solid mid-orange (developed, a long plateau).
        ///   • Lats / rhomboids / upper back — trained hard early, then
        ///     dropped four weeks ago ⇒ pale (adaptation faded past the
        ///     grace window).
        static func seedShowcase(into context: ModelContext) {
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            )
            let existing = (try? context.fetch(descriptor)) ?? []
            guard existing.isEmpty else { return }

            let now = Date()
            let calendar = Calendar.current

            /// One progressive training block: `count` sessions spread from
            /// `startDaysAgo` (oldest, base weights) to `endDaysAgo`
            /// (newest, base + `overload`). A zero overload models a fixed
            /// program that plateaus.
            func block(
                _ lifts: [(name: String, group: MuscleGroup, weight: Double)],
                startDaysAgo: Int, endDaysAgo: Int, count: Int,
                overload: Double, sets: Int, reps: Int
            ) {
                guard count > 0 else { return }
                for i in 0 ..< count {
                    let frac = count == 1 ? 1.0 : Double(i) / Double(count - 1)
                    let daysAgo = Int((Double(startDaysAgo) - frac * Double(startDaysAgo - endDaysAgo)).rounded())
                    let bump = frac * overload
                    guard
                        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                        let started = calendar.date(byAdding: .hour, value: -1, to: day)
                    else { continue }

                    let exercises: [Exercise] = lifts.enumerated().map { idx, lift in
                        let exercise = debugCatalogExercise(
                            named: lift.name,
                            plannedSets: sets,
                            plannedReps: reps,
                            plannedWeight: lift.weight + bump,
                            sortOrder: idx
                        )
                        for set in exercise.sets {
                            set.isCompleted = true
                        }
                        return exercise
                    }
                    let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: started)
                    session.completedAt = started.addingTimeInterval(40 * 60 + Double.random(in: 0 ... 600))
                    context.insert(session)
                }
            }

            // Near-max development: a long, steeply progressive squat block
            // (closely spaced so little fades between sessions) drives the
            // quads / glutes adaptation to ~0.87 — the deep, vivid-orange
            // end of the ramp, clearly the most-developed region on
            // the body. The extreme top weight is a deliberate artefact of
            // keeping overload alive long enough to reach ceiling.
            block([("Barbell Back Squat", .legs, 185)],
                  startDaysAgo: 120, endDaysAgo: 1, count: 55, overload: 555, sets: 6, reps: 6)

            // Keep the independently modeled hip-abductor regions visible.
            // This catches regressions where the large TFL surface is left
            // gray or incorrectly shares Glute Med's primary intensity.
            block([("Pressure-Biofeedback Side-Lying Hip Abduction", .legs, 90)],
                  startDaysAgo: 30, endDaysAgo: 2, count: 6, overload: 20, sets: 3, reps: 15)

            // Developed: a progressive press block.
            block([("Barbell Bench Press", .chest, 135),
                   ("Incline Barbell Bench Press", .chest, 95),
                   ("Seated Dumbbell Overhead Press", .shoulders, 75)],
                  startDaysAgo: 56, endDaysAgo: 6, count: 11, overload: 55, sets: 4, reps: 8)

            // Moderate development (lower body): a light, brief raise block.
            block([("Standing Unilateral Machine Calf Raise", .legs, 70)],
                  startDaysAgo: 30, endDaysAgo: 9, count: 4, overload: 15, sets: 3, reps: 10)

            // Plateau: identical load for fourteen sessions ⇒ developed but
            // no longer climbing — a steady mid-orange.
            block([("Supinated Straight-Bar Cable Curl", .arms, 65),
                   ("Single-Arm Supinated Cable Triceps Pushdown", .arms, 55)],
                  startDaysAgo: 60, endDaysAgo: 6, count: 14, overload: 0, sets: 3, reps: 10)

            // Fading: trained hard early, abandoned four weeks ago.
            block([("Barbell Bent-Over Row", .back, 135)],
                  startDaysAgo: 70, endDaysAgo: 28, count: 6, overload: 30, sets: 4, reps: 8)

            try? context.saveOrRollback()
        }

        /// A focused seed for the Today "PR-proximity" line on the Up Next
        /// card. Builds an old Bench Press record, then a climbing-back
        /// block that hasn't caught up (a projected, non-fresh PR with a
        /// real weight gap), plus a template pinned to today containing
        /// that lift so the card surfaces "N lb from a Bench Press PR".
        /// Drive it with `--seed-pr`.
        static func seedPRProximity(into context: ModelContext) {
            let sessionDescriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.completedAt != nil }
            )
            let existingSessions = (try? context.fetch(sessionDescriptor)) ?? []
            guard existingSessions.isEmpty else { return }

            let now = Date()
            let calendar = Calendar.current

            // Old PR (185), a drop-off, then six sessions climbing back
            // (155→180). The recent-window fit sees only the climbing
            // tail, so the trend reads as climbing; the all-time best
            // still stands, leaving a real gap to project.
            let weights: [Double] = [185, 150, 155, 160, 165, 170, 175, 180]
            let daysAgo: [Int] = [50, 44, 38, 32, 26, 20, 14, 8]
            for (w, d) in zip(weights, daysAgo) {
                guard
                    let day = calendar.date(byAdding: .day, value: -d, to: now),
                    let started = calendar.date(byAdding: .hour, value: -1, to: day)
                else { continue }
                let exercise = debugCatalogExercise(
                    named: "Barbell Bench Press",
                    plannedSets: 1,
                    plannedReps: 5,
                    plannedWeight: w,
                    sortOrder: 0
                )
                for set in exercise.sets {
                    set.isCompleted = true
                }
                let session = WorkoutSession(exercises: [exercise], restDuration: 90, startedAt: started)
                session.completedAt = started.addingTimeInterval(30 * 60)
                context.insert(session)
            }

            // A template pinned to today containing the near-PR lift, so
            // Up Next resolves to a startable workout with the lift in it.
            let todayWeekday = calendar.component(.weekday, from: now)
            let template = WorkoutTemplate(name: "Bench Day", sortOrder: 0)
            template.scheduledWeekdays = [todayWeekday]
            context.insert(template)
            let templateExercise = debugCatalogTemplateExercise(
                named: "Barbell Bench Press",
                plannedSets: 5,
                plannedReps: 5,
                plannedWeight: 180,
                sortOrder: 0
            )
            template.exercises.append(templateExercise)

            try? context.saveOrRollback()
        }

        /// A small template library exercising every TemplateCard tier:
        /// one plan pinned to today (card + Start), one pinned to other
        /// weekdays (quiet row with schedule text), one unscheduled.
        /// Drive it with `--seed-templates`.
        static func seedTemplates(into context: ModelContext) {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
            guard existing.isEmpty else { return }

            let calendar = Calendar.current
            let today = calendar.component(.weekday, from: Date())
            let plusDays: (Int) -> Int = { ((today - 1 + $0) % 7) + 1 }

            let lower = WorkoutTemplate(name: "Lower Day B", sortOrder: 0)
            lower.scheduledWeekdays = [today, plusDays(3)].sorted()
            lower.exercises = [
                debugCatalogTemplateExercise(named: "Barbell Back Squat", plannedSets: 4, plannedReps: 5, plannedWeight: 185, sortOrder: 0),
                debugCatalogTemplateExercise(named: "Barbell Hip Thrust", plannedSets: 3, plannedReps: 8, plannedWeight: 135, sortOrder: 1),
                debugCatalogTemplateExercise(named: "Barbell Front Squat", plannedSets: 3, plannedReps: 10, plannedWeight: 135, sortOrder: 2),
            ]
            context.insert(lower)

            let upper = WorkoutTemplate(name: "Upper Day A", sortOrder: 1)
            upper.scheduledWeekdays = [plusDays(2), plusDays(5)].sorted()
            let upperBench = debugCatalogTemplateExercise(named: "Barbell Bench Press", plannedSets: 4, plannedReps: 6, plannedWeight: 155, sortOrder: 0)
            let upperRow = debugCatalogTemplateExercise(named: "Barbell Bent-Over Row", plannedSets: 3, plannedReps: 8, plannedWeight: 115, sortOrder: 1)
            // Bench + Row paired as a superset so the template seam and
            // the A1/A2 tags have a live example in the seeded library.
            let upperPair = UUID()
            upperBench.supersetID = upperPair
            upperRow.supersetID = upperPair
            upper.exercises = [
                upperBench,
                upperRow,
                debugCatalogTemplateExercise(named: "Seated Dumbbell Overhead Press", plannedSets: 3, plannedReps: 8, plannedWeight: 85, sortOrder: 2),
                debugCatalogTemplateExercise(named: "Supinated Straight-Bar Cable Curl", plannedSets: 3, plannedReps: 10, plannedWeight: 60, sortOrder: 3),
            ]
            context.insert(upper)

            let core = WorkoutTemplate(name: "Core A", sortOrder: 2)
            core.exercises = [
                debugCatalogTemplateExercise(named: "30-Degree Curl-Up", plannedSets: 3, plannedReps: 12, plannedWeight: 0, sortOrder: 0),
            ]
            context.insert(core)

            try? context.saveOrRollback()
        }

        private static func templateExercise(for group: MuscleGroup, variant _: Int) -> (name: String, weight: Double) {
            switch group {
            case .chest: ("Barbell Bench Press", 135)
            case .back: ("Barbell Bent-Over Row", 115)
            case .shoulders: ("Seated Dumbbell Overhead Press", 95)
            case .legs: ("Barbell Back Squat", 185)
            case .arms: ("Supinated Straight-Bar Cable Curl", 65)
            case .core: ("30-Degree Curl-Up", 0)
            }
        }
    }

#endif

//
//  DebugSeed.swift
//  vivobody
//
//  Debug-only seed data and UI-test support. Extracted from
//  vivobodyApp.swift so the @main entry point reads at a glance.
//  All types are inside `#if DEBUG` and never ship in Release.
//

import Foundation
import SwiftData

#if DEBUG

/// UI-test and verification helpers driven by launch arguments.
/// Reset wipes the store for a clean test base; seeds insert focused
/// workout states; requestedTab chooses a capture start tab.
enum UITestSupport {
    static func requestedTab() -> AppTab? {
        guard let index = CommandLine.arguments.firstIndex(of: "--verify-tab"),
              CommandLine.arguments.indices.contains(index + 1)
        else { return nil }
        return AppTab(rawValue: CommandLine.arguments[index + 1])
    }

    static func resetIfRequested(in context: ModelContext) {
        guard CommandLine.arguments.contains("--ui-test-reset") else { return }
        // UI tests must land on the tab shell, not the first-launch
        // welcome cover. Without this, tests only pass when the base
        // simulator happens to have completed onboarding — the cover
        // sits over the MiniBar and swallows its taps.
        UserDefaults.standard.set(true, forKey: SettingsKey.onboardingCompleted)
        deleteAll(WorkoutSession.self, in: context)
        deleteAll(WorkoutTemplate.self, in: context)
        deleteAll(ExerciseCatalogItem.self, in: context)
        deleteAll(BodyWeightEntry.self, in: context)
        try? context.save()
    }

    static func seedIfRequested(in context: ModelContext) {
        if CommandLine.arguments.contains("--ui-test-active-partial") {
            seedActivePartial(in: context)
        }
        if CommandLine.arguments.contains("--ui-test-scheduled-template") {
            seedScheduledTemplate(in: context)
        }
    }

    private static func seedActivePartial(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt == nil }
        ))) ?? []
        guard existing.isEmpty else { return }

        let exercise = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 2,
            plannedReps: 8,
            plannedWeight: 135,
            sortOrder: 0
        )
        if let first = exercise.orderedSets.first {
            first.isCompleted = true
        }
        let session = WorkoutSession(exercises: [exercise], restDuration: 90)
        context.insert(session)
        try? context.save()
    }

    private static func seedScheduledTemplate(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        guard existing.isEmpty else { return }

        let template = WorkoutTemplate(
            name: "Scheduled Test",
            exercises: [
                TemplateExercise(
                    name: "Bench Press",
                    group: .chest,
                    plannedSets: 2,
                    plannedReps: 8,
                    plannedWeight: 135,
                    sortOrder: 0
                )
            ]
        )
        template.scheduledWeekdays = [Calendar.current.component(.weekday, from: Date())]
        context.insert(template)
        try? context.save()
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
            (0,  -1, [.chest, .back, .shoulders, .legs]),
            (0,  -2, [.chest, .back, .shoulders, .legs]),
            (0,  -3, [.chest, .back, .shoulders, .legs]),
            (1,   0, [.arms, .core]),
            (2,   0, [.chest, .shoulders]),
            (3,   0, [.legs]),
            (5,   0, [.back, .arms]),
            (8,   0, [.chest, .back, .legs]),
            (14,  0, [.shoulders, .arms]),
            (28,  0, [.legs, .core]),
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
                let exercise = Exercise(
                    name: template.name,
                    group: group,
                    plannedSets: 3,
                    plannedReps: 8,
                    plannedWeight: template.weight + overloadStep,
                    sortOrder: idx
                )
                for set in exercise.sets { set.isCompleted = true }
                return exercise
            }

            let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: started)
            session.completedAt = started.addingTimeInterval(40 * 60 + Double.random(in: 0...600))
            context.insert(session)
        }
        try? context.save()
    }

    /// A deliberately lopsided ~10-week training history engineered so
    /// every render channel lights up at once on a different body
    /// region — the fastest way to eyeball the full colour palette.
    /// Drive it with `--seed-showcase`.
    ///
    ///   • Quads / glutes — heavy, progressive squats right up to a few
    ///     days ago ⇒ a deep, vivid orange (well developed).
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

        // One progressive training block: `count` sessions spread from
        // `startDaysAgo` (oldest, base weights) to `endDaysAgo`
        // (newest, base + `overload`). A zero overload models a fixed
        // program that plateaus.
        func block(
            _ lifts: [(name: String, group: MuscleGroup, weight: Double)],
            startDaysAgo: Int, endDaysAgo: Int, count: Int,
            overload: Double, sets: Int, reps: Int
        ) {
            guard count > 0 else { return }
            for i in 0..<count {
                let frac = count == 1 ? 1.0 : Double(i) / Double(count - 1)
                let daysAgo = Int((Double(startDaysAgo) - frac * Double(startDaysAgo - endDaysAgo)).rounded())
                let bump = frac * overload
                guard
                    let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                    let started = calendar.date(byAdding: .hour, value: -1, to: day)
                else { continue }

                let exercises: [Exercise] = lifts.enumerated().map { idx, lift in
                    let exercise = Exercise(
                        name: lift.name,
                        group: lift.group,
                        plannedSets: sets,
                        plannedReps: reps,
                        plannedWeight: lift.weight + bump,
                        sortOrder: idx
                    )
                    for set in exercise.sets { set.isCompleted = true }
                    return exercise
                }
                let session = WorkoutSession(exercises: exercises, restDuration: 90, startedAt: started)
                session.completedAt = started.addingTimeInterval(40 * 60 + Double.random(in: 0...600))
                context.insert(session)
            }
        }

        // Near-max development: a long, steeply progressive squat block
        // (closely spaced so little fades between sessions) drives the
        // quads / glutes adaptation to ~0.87 — the deep, vivid-orange
        // end of the ramp, clearly the most-developed region on
        // the body. The extreme top weight is a deliberate artefact of
        // keeping overload alive long enough to reach ceiling.
        block([("Barbell Full Squat", .legs, 185)],
              startDaysAgo: 120, endDaysAgo: 1, count: 55, overload: 555, sets: 6, reps: 6)

        // Developed: a progressive press block.
        block([("Bench Press", .chest, 135),
               ("Incline Bench Press - Barbell", .chest, 95),
               ("Shoulder Press, Dumbbells", .shoulders, 75)],
              startDaysAgo: 56, endDaysAgo: 6, count: 11, overload: 55, sets: 4, reps: 8)

        // Moderate development (lower body): a light, brief raise block.
        block([("Standing Calf Raises", .legs, 70)],
              startDaysAgo: 30, endDaysAgo: 9, count: 4, overload: 15, sets: 3, reps: 10)

        // Plateau: identical load for fourteen sessions ⇒ developed but
        // no longer climbing — a steady mid-orange.
        block([("Biceps Curls With Barbell", .arms, 65),
               ("Triceps Pushdown", .arms, 55)],
              startDaysAgo: 60, endDaysAgo: 6, count: 14, overload: 0, sets: 3, reps: 10)

        // Fading: trained hard early, abandoned four weeks ago.
        block([("Barbell Row (Overhand)", .back, 135)],
              startDaysAgo: 70, endDaysAgo: 28, count: 6, overload: 30, sets: 4, reps: 8)

        try? context.save()
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
        let daysAgo: [Int]    = [50,  44,  38,  32,  26,  20,  14,  8 ]
        for (w, d) in zip(weights, daysAgo) {
            guard
                let day = calendar.date(byAdding: .day, value: -d, to: now),
                let started = calendar.date(byAdding: .hour, value: -1, to: day)
            else { continue }
            let exercise = Exercise(
                name: "Bench Press",
                group: .chest,
                plannedSets: 1,
                plannedReps: 5,
                plannedWeight: w,
                sortOrder: 0
            )
            for set in exercise.sets { set.isCompleted = true }
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
        let templateExercise = TemplateExercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 5,
            plannedReps: 5,
            plannedWeight: 180,
            sortOrder: 0
        )
        template.exercises.append(templateExercise)

        try? context.save()
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
            TemplateExercise(name: "Barbell Full Squat", group: .legs, plannedSets: 4, plannedReps: 5, plannedWeight: 185, sortOrder: 0),
            TemplateExercise(name: "Barbell Romanian Deadlift (RDL)", group: .legs, plannedSets: 3, plannedReps: 8, plannedWeight: 135, sortOrder: 1),
            TemplateExercise(name: "Leg Press", group: .legs, plannedSets: 3, plannedReps: 10, plannedWeight: 270, sortOrder: 2),
        ]
        context.insert(lower)

        let upper = WorkoutTemplate(name: "Upper Day A", sortOrder: 1)
        upper.scheduledWeekdays = [plusDays(2), plusDays(5)].sorted()
        upper.exercises = [
            TemplateExercise(name: "Bench Press", group: .chest, plannedSets: 4, plannedReps: 6, plannedWeight: 155, sortOrder: 0),
            TemplateExercise(name: "Bent Over Rowing", group: .back, plannedSets: 3, plannedReps: 8, plannedWeight: 115, sortOrder: 1),
            TemplateExercise(name: "Shoulder Press, Dumbbells", group: .shoulders, plannedSets: 3, plannedReps: 8, plannedWeight: 85, sortOrder: 2),
            TemplateExercise(name: "Biceps Curls With Barbell", group: .arms, plannedSets: 3, plannedReps: 10, plannedWeight: 60, sortOrder: 3),
        ]
        context.insert(upper)

        let core = WorkoutTemplate(name: "Core A", sortOrder: 2)
        core.exercises = [
            TemplateExercise(name: "Hanging Leg Raises", group: .core, plannedSets: 3, plannedReps: 12, plannedWeight: 0, sortOrder: 0),
        ]
        context.insert(core)

        try? context.save()
    }

    private static func templateExercise(for group: MuscleGroup, variant: Int) -> (name: String, weight: Double) {
        switch group {
        case .chest:     return ("Bench Press", 135)
        case .back:      return ("Bent Over Rowing", 115)
        case .shoulders: return ("Shoulder Press, Dumbbells", 95)
        case .legs:      return ("Barbell Full Squat", 185)
        case .arms:      return ("Biceps Curls With Barbell", 65)
        case .core:      return ("Hanging Leg Raises", 0)
        }
    }
}

#endif

//
//  vivobodyApp.swift
//  vivobody
//
//  Created by Adrian Stanciu on 18.05.2026.
//

import SwiftUI
import SwiftData

@main
struct vivobodyApp: App {
    /// The SwiftData container. Holds every archived workout. The
    /// schema declares all three @Model classes; cascade-delete
    /// relationships keep exercises and sets bound to their session.
    private let container: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            WorkoutSet.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            ExerciseCatalogItem.self,
            BodyWeightEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .preferredColorScheme(.dark)
                .warmUpKeyboardOnce()
                .task {
                    if CommandLine.arguments.contains("--seed-history") {
                        HistorySeeder.seed(into: container.mainContext)
                    } else if CommandLine.arguments.contains("--seed-tightness") {
                        HistorySeeder.seedTightness(into: container.mainContext)
                    } else if CommandLine.arguments.contains("--seed-showcase") {
                        HistorySeeder.seedShowcase(into: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
    }
}

#if DEBUG
private enum HistorySeeder {
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

    /// A five-week press-dominant block with zero pulling and zero
    /// mobility — the textbook way to wind functional tightness into
    /// the chest and front delts (neglected rhomboids → rounded
    /// shoulders) and the quads. Exactly the state the cool strain rim
    /// and the Today tightness line exist to surface. Drive it with
    /// `--seed-tightness`.
    static func seedTightness(into context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let now = Date()
        let calendar = Calendar.current

        // All contraction-biased, all confirmed in the catalog so the
        // muscle map resolves. Nothing here lengthens a muscle under
        // load and nothing pulls — so the chest tightens unopposed.
        let lifts: [(name: String, group: MuscleGroup, weight: Double)] = [
            ("Bench Press", .chest, 135),
            ("Incline Bench Press - Barbell", .chest, 95),
            ("Overhead Press", .shoulders, 85),
            ("Triceps Pushdown", .arms, 60),
            ("Leg Extension", .legs, 90),
        ]

        // 15 sessions, ~every 2.5 days, progressively heavier toward
        // now (index 0 is the oldest, so the overload bonus grows with
        // the index and reads as honest progression).
        let count = 15
        for i in 0..<count {
            let daysAgo = Int(Double(count - 1 - i) * 2.5)
            guard
                let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                let started = calendar.date(byAdding: .hour, value: -1, to: day)
            else { continue }

            let overload = Double(i) * 2.5
            let exercises: [Exercise] = lifts.enumerated().map { idx, lift in
                let exercise = Exercise(
                    name: lift.name,
                    group: lift.group,
                    plannedSets: 4,
                    plannedReps: 8,
                    plannedWeight: lift.weight + overload,
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
    ///     days ago ⇒ a deep, vivid orange (well developed), and
    ///     supple (a squat lengthens under load, so it relieves).
    ///   • Chest / front delts — a progressive press block with zero
    ///     pulling and zero mobility ⇒ developed orange that slowly
    ///     pulses (tight: contraction-biased loading, neglected
    ///     rhomboids amplify it).
    ///   • Calves — progressive raises, shins never trained ⇒ a second
    ///     pulsing tight region low on the legs.
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

        // Developed + tight: press-only, no pulling, no mobility.
        block([("Bench Press", .chest, 135),
               ("Incline Bench Press - Barbell", .chest, 95),
               ("Overhead Press", .shoulders, 75)],
              startDaysAgo: 56, endDaysAgo: 6, count: 11, overload: 55, sets: 4, reps: 8)

        // Tight (lower body): progressive raises, shins never trained.
        block([("Standing Calf Raises", .legs, 120)],
              startDaysAgo: 40, endDaysAgo: 2, count: 8, overload: 40, sets: 4, reps: 12)

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

    private static func templateExercise(for group: MuscleGroup, variant: Int) -> (name: String, weight: Double) {
        switch group {
        case .chest:     return ("Bench Press", 135)
        case .back:      return ("Barbell Row", 115)
        case .shoulders: return ("Overhead Press", 95)
        case .legs:      return ("Back Squat", 185)
        case .arms:      return ("Barbell Curl", 65)
        case .core:      return ("Hanging Leg Raise", 0)
        }
    }
}
#endif

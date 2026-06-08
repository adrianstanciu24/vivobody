//
//  MuscleDevelopmentTests.swift
//  vivobodyTests
//
//  A TIME MACHINE for the muscle-development model. The model's whole
//  point is behaviour over weeks and months (slow build, fade after a
//  layoff, plateau without progression) — impossible to feel in a
//  simulator. So instead we drive it with a virtual clock: every
//  workout is stamped at a chosen day and the state is evaluated "as
//  of" any later day. Fast-forwarding a quarter is a one-liner.
//
//  The suites:
//    • Build      — colour accrues gradually, never maxes in one go.
//    • Detraining — holds through a ~1-week grace, then fades, deeper
//                   the longer the layoff.
//    • Plateau    — a fixed program tapers to a sub-max ceiling and
//                   loses momentum; progressive overload keeps climbing.
//    • Momentum   — growing > 0, plateau ≈ 0, detraining < 0.
//    • Fatigue    — the acute glow blooms and fades within days.
//    • Invariants — closed-form decay is order-independent (semigroup),
//                   and the model is deterministic.
//    • Colour     — the perceptual map behaves (lightness↑ with
//                   development, chroma↑ with momentum, bloom = fatigue).
//

import Foundation
import Testing
@testable import vivobody

struct MuscleDevelopmentTests {

    // MARK: - Virtual clock

    /// Fixed epoch so every test is reproducible.
    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Build: colour accrues over time

    /// A single workout must move the chest only a fraction of the way
    /// — never to the ceiling. This is the core "no instant max" rule.
    @Test func oneWorkoutDoesNotMaxAdaptation() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135)])
        let state = MuscleDevelopment.simulate(from: [s], now: day(0))
        let chest = state.fibers[.pectorals]?.adaptation ?? 0
        #expect(chest > 0.05)        // it did register
        #expect(chest < 0.45)        // but nowhere near full
    }

    /// Under steady progressive overload, development rises at every
    /// checkpoint — and is still below the ceiling early on.
    @Test func progressiveOverloadBuildsMonotonically() {
        let program = progressive(sessions: 14, startWeight: 135, step: 5, everyDays: 3.5)
        let a1 = adaptation(.pectorals, afterFirst: 1, of: program)
        let a4 = adaptation(.pectorals, afterFirst: 4, of: program)
        let a8 = adaptation(.pectorals, afterFirst: 8, of: program)
        let a14 = adaptation(.pectorals, afterFirst: 14, of: program)

        #expect(a1 < a4)
        #expect(a4 < a8)
        #expect(a8 < a14)
        #expect(a1 < 0.45)           // early on, far from full
        #expect(a14 > a1 + 0.2)      // meaningful accrued growth
    }

    // MARK: - Detraining: the ~1-week grace, then fade

    /// Trained hard, then neglected: colour barely moves inside the
    /// first week, then fades, and fades further the longer the layoff.
    @Test func detrainingHoldsThenFades() {
        let program = progressive(sessions: 12, startWeight: 135, step: 5, everyDays: 3.5)
        let last = program.last!.completedAt!

        func chest(daysAfterLast d: Double) -> Double {
            MuscleDevelopment.simulate(from: program, now: last.addingTimeInterval(d * 86_400))
                .fibers[.pectorals]?.adaptation ?? 0
        }

        let fresh = chest(daysAfterLast: 0)
        let week = chest(daysAfterLast: 5)
        let threeWeeks = chest(daysAfterLast: 21)
        let twoMonths = chest(daysAfterLast: 60)

        // Grace: holds most of its colour through the first ~week.
        #expect(week > 0.95 * fresh)
        // Then a clear decline that deepens with time.
        #expect(threeWeeks < 0.92 * fresh)
        #expect(twoMonths < 0.65 * fresh)
        #expect(week > threeWeeks)
        #expect(threeWeeks > twoMonths)
    }

    // MARK: - Plateau vs. progression

    /// Same workout forever tapers to a sub-maximal ceiling; pushing
    /// the load keeps climbing past it. This is the "same reps → you
    /// stop growing" signal.
    @Test func fixedProgramPlateausBelowProgressiveOverload() {
        let fixed = progressive(sessions: 16, startWeight: 135, step: 0, everyDays: 3.5)
        let pushed = progressive(sessions: 16, startWeight: 135, step: 5, everyDays: 3.5)

        let fixedChest = adaptation(.pectorals, afterFirst: 16, of: fixed)
        let pushedChest = adaptation(.pectorals, afterFirst: 16, of: pushed)

        #expect(pushedChest > fixedChest)
        #expect(fixedChest < 0.85)               // a fixed load never tops out
        #expect(fixedChest > 0.2)                // but it did develop something
    }

    /// Diminishing returns: on a fixed load, the growth between late
    /// sessions is far smaller than between early ones.
    @Test func fixedProgramShowsDiminishingReturns() {
        let fixed = progressive(sessions: 16, startWeight: 135, step: 0, everyDays: 3.5)
        let earlyDelta = adaptation(.pectorals, afterFirst: 4, of: fixed)
            - adaptation(.pectorals, afterFirst: 2, of: fixed)
        let lateDelta = adaptation(.pectorals, afterFirst: 16, of: fixed)
            - adaptation(.pectorals, afterFirst: 14, of: fixed)
        #expect(earlyDelta > lateDelta)
        #expect(lateDelta < 0.02)                // essentially flat by the end
    }

    /// Absolute-load ceiling: the same muscle trained heavy plateaus
    /// markedly more developed than when trained with trivial loads,
    /// even though both programs are fixed (non-progressing).
    @Test func heavierTrainingReachesHigherCeiling() {
        func fixedQuads(_ name: String, reps: Int, weight: Double) -> [WorkoutSession] {
            (0..<18).map { i in
                session(at: day(Double(i) * 3.5),
                        [lift(name, .legs, sets: 3, reps: reps, weight: weight)])
            }
        }
        let heavy = fixedQuads("Squats", reps: 5, weight: 315)
        let light = fixedQuads("Leg Extension", reps: 15, weight: 30)

        let heavyQuads = adaptation(.quads, afterFirst: 18, of: heavy)
        let lightQuads = adaptation(.quads, afterFirst: 18, of: light)

        #expect(heavyQuads > lightQuads + 0.1)
        #expect(lightQuads > 0)               // light work still develops a little
        #expect(lightQuads < 0.6)             // ...but is ceiling-capped low
    }

    // MARK: - Momentum channel

    /// Growing muscles read vivid (momentum > 0), plateaued ones go
    /// flat (≈ 0), detraining ones go cool (< 0).
    @Test func momentumDistinguishesGrowthPlateauAndLoss() {
        let pushed = progressive(sessions: 16, startWeight: 135, step: 5, everyDays: 3.5)
        let fixed = progressive(sessions: 16, startWeight: 135, step: 0, everyDays: 3.5)

        let growing = MuscleDevelopment
            .simulate(from: pushed, now: pushed.last!.completedAt!)
            .momentum(.pectorals)
        let plateau = MuscleDevelopment
            .simulate(from: fixed, now: fixed.last!.completedAt!)
            .momentum(.pectorals)
        let losing = MuscleDevelopment
            .simulate(from: pushed, now: pushed.last!.completedAt!.addingTimeInterval(60 * 86_400))
            .momentum(.pectorals)

        #expect(growing > 0.1)
        #expect(abs(plateau) < growing)
        #expect(plateau < 0.2)
        #expect(losing < 0)
        #expect(growing > losing)
    }

    // MARK: - Fatigue (acute glow)

    /// The bloom is bright right after training and almost gone a week
    /// later — and it fades far faster than the underlying development.
    @Test func fatigueBloomsThenFadesFasterThanAdaptation() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135)])

        let fresh = MuscleDevelopment.simulate(from: [s], now: day(0))
        let week = MuscleDevelopment.simulate(from: [s], now: day(7))

        let freshFatigue = fresh.fibers[.pectorals]?.fatigue ?? 0
        let weekFatigue = week.fibers[.pectorals]?.fatigue ?? 0
        let freshAdapt = fresh.fibers[.pectorals]?.adaptation ?? 0
        let weekAdapt = week.fibers[.pectorals]?.adaptation ?? 0

        #expect(freshFatigue > 0.4)
        #expect(weekFatigue < 0.2 * freshFatigue)     // glow nearly gone
        #expect(weekAdapt > 0.95 * freshAdapt)         // development held
    }

    // MARK: - Invariants

    /// Closed-form decay is a semigroup: advancing 0→90 days in one
    /// step equals advancing through intermediate stops. This is what
    /// makes the model independent of how often the app is opened.
    @Test func decayIsOrderIndependent() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135)])
        let base = MuscleDevelopment.simulate(from: [s], now: day(0))

        var oneStep = base
        MuscleDevelopment.advance(&oneStep, to: day(90))

        var manySteps = base
        for d in stride(from: 3.0, through: 90.0, by: 3.0) {
            MuscleDevelopment.advance(&manySteps, to: day(d))
        }

        let a = oneStep.fibers[.pectorals]!.adaptation
        let b = manySteps.fibers[.pectorals]!.adaptation
        #expect(abs(a - b) < 1e-9)

        let sa = oneStep.fibers[.pectorals]!.adaptationSlow
        let sb = manySteps.fibers[.pectorals]!.adaptationSlow
        #expect(abs(sa - sb) < 1e-9)
    }

    /// Same history in, same channels out.
    @Test func simulationIsDeterministic() {
        let program = progressive(sessions: 10, startWeight: 135, step: 5, everyDays: 3.5)
        let now = program.last!.completedAt!.addingTimeInterval(10 * 86_400)
        let a = MuscleDevelopment.simulate(from: program, now: now)
        let b = MuscleDevelopment.simulate(from: program, now: now)
        for muscle in Set(a.fibers.keys).union(b.fibers.keys) {
            #expect(a.channels(muscle) == b.channels(muscle))
        }
    }

    /// Session order in the input array doesn't matter — they're
    /// sorted by completion time.
    @Test func sessionOrderDoesNotMatter() {
        let program = progressive(sessions: 8, startWeight: 135, step: 5, everyDays: 3.5)
        let now = program.last!.completedAt!
        let forward = MuscleDevelopment.simulate(from: program, now: now).momentum(.pectorals)
        let shuffled = MuscleDevelopment.simulate(from: program.reversed(), now: now).momentum(.pectorals)
        #expect(abs(forward - shuffled) < 1e-9)
    }

    @Test func emptyHistoryProducesEmptyState() {
        let state = MuscleDevelopment.simulate(from: [])
        #expect(state.fibers.isEmpty)
        #expect(state.intensities.isEmpty)
        #expect(MuscleDevelopment.nodeIntensities(from: []).isEmpty)
    }

    /// Node-keyed output paints both sides of a worked muscle and
    /// leaves untrained meshes out.
    @Test func nodeIntensitiesPaintBothSides() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135)])
        let nodes = MuscleDevelopment.nodeIntensities(from: [s], now: day(0))
        #expect((nodes["Pectoralis_Major_L"] ?? 0) > 0)
        #expect((nodes["Pectoralis_Major_R"] ?? 0) > 0)
        #expect(nodes["Vastus_Lateralis_L"] == nil)
    }

    /// A muscle's session stimulus scales with its graded involvement
    /// weight: from a bench press the assisting triceps and front delt
    /// earn exact fractions of the chest's prime-mover credit. Weights
    /// come from the catalog so the test follows the shipped data.
    @Test func gradedInvolvementScalesSessionStimulus() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135)])
        let stim = MuscleDevelopment.sessionStimulus(s, bodyweight: 155)
        let w = Muscle.involvement(forExerciseNamed: "Bench Press").weights
        let chest = stim[.pectorals] ?? 0
        #expect(chest > 0)
        #expect(abs((stim[.triceps] ?? 0) - (w[.triceps]! / w[.pectorals]!) * chest) < 1e-9)
        #expect(abs((stim[.deltoids] ?? 0) - (w[.deltoids]! / w[.pectorals]!) * chest) < 1e-9)
        // The assistors receive strictly less stimulus than the prime mover.
        #expect((stim[.triceps] ?? 0) < chest)
    }

    // MARK: - Colour mapping

    @Test func lightnessRisesWithDevelopment() {
        let dim = MuscleColor.oklch(for: .init(adaptation: 0.2, momentum: 0, fatigue: 0))
        let bright = MuscleColor.oklch(for: .init(adaptation: 0.85, momentum: 0, fatigue: 0))
        #expect(bright.lightness > dim.lightness)
    }

    @Test func chromaRisesWithMomentum() {
        let growing = MuscleColor.oklch(for: .init(adaptation: 0.6, momentum: 0.8, fatigue: 0))
        let steady = MuscleColor.oklch(for: .init(adaptation: 0.6, momentum: 0, fatigue: 0))
        let losing = MuscleColor.oklch(for: .init(adaptation: 0.6, momentum: -0.8, fatigue: 0))
        #expect(growing.chroma > steady.chroma)
        #expect(steady.chroma > losing.chroma)
    }

    @Test func untrainedMuscleIsNeutralGrey() {
        let c = MuscleColor.rgb(for: .init(adaptation: 0, momentum: 0, fatigue: 0))
        #expect(abs(c.red - c.green) < 1e-6)
        #expect(abs(c.green - c.blue) < 1e-6)
    }

    @Test func fatigueDrivesEmissiveBloom() {
        let c = MuscleColor.rgb(for: .init(adaptation: 0.6, momentum: 0.2, fatigue: 0.7))
        #expect(abs(c.emissive - 0.7) < 1e-9)
    }

    /// Every colour in a full channel sweep stays in gamut `0...1`.
    @Test func colourStaysInGamut() {
        for a in stride(from: 0.0, through: 1.0, by: 0.2) {
            for m in stride(from: -1.0, through: 1.0, by: 0.5) {
                for f in stride(from: 0.0, through: 1.0, by: 0.5) {
                    let c = MuscleColor.rgb(for: .init(adaptation: a, momentum: m, fatigue: f))
                    #expect(c.red >= 0 && c.red <= 1)
                    #expect(c.green >= 0 && c.green <= 1)
                    #expect(c.blue >= 0 && c.blue <= 1)
                }
            }
        }
    }

    // MARK: - Helpers

    /// One completed, single-exercise (or multi-) session stamped at a date.
    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// A completed lift: every planned set marked done at the given RIR.
    private func lift(_ name: String, _ group: MuscleGroup, sets: Int, reps: Int, weight: Double, rir: Int = 2) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true; $0.repsInReserve = rir }
        return ex
    }

    /// A bench-press program: `sessions` workouts spaced `everyDays`
    /// apart, the load climbing by `step` lb each time (step 0 = a
    /// fixed, non-progressing program).
    private func progressive(sessions n: Int, startWeight: Double, step: Double, everyDays: Double) -> [WorkoutSession] {
        (0..<n).map { i in
            session(
                at: day(Double(i) * everyDays),
                [lift("Bench Press", .chest, sets: 3, reps: 8, weight: startWeight + Double(i) * step)]
            )
        }
    }

    /// Chest adaptation after the first `k` sessions of a program,
    /// evaluated the instant the kth session finishes (no decay).
    private func adaptation(_ muscle: Muscle, afterFirst k: Int, of program: [WorkoutSession]) -> Double {
        let subset = Array(program.prefix(k))
        guard let last = subset.last?.completedAt else { return 0 }
        return MuscleDevelopment.simulate(from: subset, now: last).fibers[muscle]?.adaptation ?? 0
    }
}

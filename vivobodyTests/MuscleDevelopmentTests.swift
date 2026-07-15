//
//  MuscleDevelopmentTests.swift
//  vivobodyTests
//
//  A TIME MACHINE for the muscle-development model. The model's whole
//  point is behaviour over weeks and months (slow build, fade after a
//  layoff, convergence at a sustained volume) — impossible to feel in
//  a simulator. So instead we drive it with a virtual clock: every
//  workout is stamped at a chosen day and the state is evaluated "as
//  of" any later day. Fast-forwarding a quarter is a one-liner.
//
//  The suites:
//    • Build      — colour accrues gradually, never maxes in one go,
//                   and scales with set volume.
//    • Detraining — holds through a ~1-week grace, then fades, deeper
//                   the longer the layoff.
//    • Convergence— consistent training shows diminishing returns and
//                   fills in over months at the landmark band.
//    • Frequency  — the same weekly volume develops the same, however
//                   it is split across sessions.
//    • Currency   — effective sets match `MuscleVolume`'s crediting,
//                   scaled by graded involvement.
//    • Invariants — constant-rate decay is order-independent (semigroup),
//                   and the model is deterministic.
//    • Colour     — the perceptual map behaves (the orange deepens
//                   with development).
//

import Foundation
import Testing
@testable import vivobody

@MainActor
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
        let chest = state.adaptation(.pectorals)
        #expect(chest > 0.03)        // it did register
        #expect(chest < 0.3)         // but nowhere near full
    }

    /// Under a steady training cadence, development rises at every
    /// checkpoint — and is still far from full early on.
    @Test func consistentTrainingBuildsMonotonically() {
        let program = benchProgram(sessions: 14, everyDays: 3.5)
        let a1 = adaptation(.pectorals, afterFirst: 1, of: program)
        let a4 = adaptation(.pectorals, afterFirst: 4, of: program)
        let a8 = adaptation(.pectorals, afterFirst: 8, of: program)
        let a14 = adaptation(.pectorals, afterFirst: 14, of: program)

        #expect(a1 < a4)
        #expect(a4 < a8)
        #expect(a8 < a14)
        #expect(a1 < 0.3)            // early on, far from full
        #expect(a14 > 2.5 * a1)      // meaningful accrued growth
    }

    /// Development scales with set volume: the same cadence at higher
    /// per-session sets develops the muscle visibly further.
    @Test func moreVolumeDevelopsMore() {
        let low = benchProgram(sessions: 10, everyDays: 3.5, sets: 2)
        let high = benchProgram(sessions: 10, everyDays: 3.5, sets: 5)

        let lowChest = adaptation(.pectorals, afterFirst: 10, of: low)
        let highChest = adaptation(.pectorals, afterFirst: 10, of: high)

        #expect(highChest > lowChest + 0.05)
        #expect(highChest <= 1.0)
    }

    // MARK: - Detraining: the ~1-week grace, then fade

    /// Trained hard, then neglected: colour barely moves inside the
    /// first week, then fades, and fades further the longer the layoff.
    @Test func detrainingHoldsThenFades() {
        let program = benchProgram(sessions: 12, everyDays: 3.5)
        let last = program.last!.completedAt!

        func chest(daysAfterLast d: Double) -> Double {
            MuscleDevelopment.simulate(from: program, now: last.addingTimeInterval(d * 86_400))
                .adaptation(.pectorals)
        }

        let fresh = chest(daysAfterLast: 0)
        let week = chest(daysAfterLast: 5)
        let threeWeeks = chest(daysAfterLast: 21)
        let twoMonths = chest(daysAfterLast: 60)

        // Grace: holds most of its colour through the first ~week.
        #expect(week > 0.95 * fresh)
        // Then a clear decline that deepens with time.
        #expect(threeWeeks < 0.92 * fresh)
        #expect(twoMonths < 0.70 * fresh)
        #expect(week > threeWeeks)
        #expect(threeWeeks > twoMonths)
    }

    // MARK: - Convergence at sustained volume

    /// Diminishing returns: at a steady volume, the growth between
    /// late sessions is far smaller than between early ones — the
    /// accumulator approaches the level that volume sustains.
    @Test func steadyVolumeShowsDiminishingReturns() {
        let program = benchProgram(sessions: 16, everyDays: 3.5)
        let earlyDelta = adaptation(.pectorals, afterFirst: 4, of: program)
            - adaptation(.pectorals, afterFirst: 2, of: program)
        let lateDelta = adaptation(.pectorals, afterFirst: 16, of: program)
            - adaptation(.pectorals, afterFirst: 14, of: program)
        #expect(earlyDelta > lateDelta)
        #expect(lateDelta < 0.02)
    }

    /// The landmark normalisation: training a muscle at the TOP of its
    /// productive weekly band, week in week out for a year, converges
    /// toward full development — and never overshoots the clamp.
    @Test func consistentOptimalVolumeConvergesTowardFull() {
        let weeklySets = Int(VolumeLandmark.landmark(for: .pectorals).optimalHigh)
        let program = (0..<52).map { i in
            session(at: day(Double(i) * 7),
                    [lift("Bench Press", .chest, sets: weeklySets, reps: 8, weight: 135)])
        }
        let chest = adaptation(.pectorals, afterFirst: 52, of: program)
        #expect(chest > 0.8)
        #expect(chest <= 1.0)
    }

    /// Recalibrated convergence (#3): training at the top of the
    /// productive band fills in over MONTHS, not years — clearly
    /// developed by ~3 months, near-full by ~6.
    @Test func optimalTrainingDevelopsWithinMonths() {
        let weekly = Int(VolumeLandmark.landmark(for: .pectorals).optimalHigh)
        func chest(afterWeeks weeks: Int) -> Double {
            let program = (0..<weeks).map { i in
                session(at: day(Double(i) * 7),
                        [lift("Bench Press", .chest, sets: weekly, reps: 8, weight: 135)])
            }
            return MuscleDevelopment.simulate(from: program, now: program.last!.completedAt!)
                .adaptation(.pectorals)
        }
        #expect(chest(afterWeeks: 6) > 0.6)    // ~0.71
        #expect(chest(afterWeeks: 13) > 0.8)   // ~0.89 by 3 months
        #expect(chest(afterWeeks: 26) > 0.95)  // ~0.99 by 6 months
    }

    // MARK: - Frequency invariance

    /// The headline property of the weekly-volume model: the SAME
    /// weekly volume, delivered 1×/2×/3× per week, converges to nearly
    /// the same development. Colour reads weekly volume, not how it is
    /// chunked into sessions (the old grace-gated model rewarded
    /// frequency by ~67% for identical weekly volume).
    @Test func sameWeeklyVolumeIsFrequencyInvariant() {
        func program(timesPerWeek: Double, setsPerSession: Int) -> [WorkoutSession] {
            let gap = 7.0 / timesPerWeek
            let count = Int(16 * timesPerWeek)
            return (0..<count).map { i in
                session(at: day(Double(i) * gap),
                        [lift("Bench Press", .chest, sets: setsPerSession, reps: 8, weight: 135)])
            }
        }
        // 12 effective chest sets per week, three ways.
        let once = program(timesPerWeek: 1, setsPerSession: 12)
        let twice = program(timesPerWeek: 2, setsPerSession: 6)
        let thrice = program(timesPerWeek: 3, setsPerSession: 4)

        func chest(_ p: [WorkoutSession]) -> Double {
            MuscleDevelopment.simulate(from: p, now: p.last!.completedAt!).adaptation(.pectorals)
        }
        let a1 = chest(once), a2 = chest(twice), a3 = chest(thrice)

        #expect(max(a1, a2, a3) - min(a1, a2, a3) < 0.04)
        #expect(a1 > 0.3)   // a real mid-ramp value, not a degenerate match at 0
    }

    // MARK: - Currency

    /// A muscle's session stimulus scales with its graded involvement
    /// weight: from a bench press the assisting triceps and front delt
    /// earn exact fractions of the chest's prime-mover credit. Weights
    /// come from the catalog so the test follows the shipped data.
    @Test func gradedInvolvementScalesSessionStimulus() {
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135)])
        let stim = MuscleDevelopment.sessionStimulus(s)
        let w = Muscle.involvement(forExerciseNamed: "Bench Press").weights
        let chest = stim[.pectorals] ?? 0
        #expect(chest > 0)
        #expect(abs((stim[.triceps] ?? 0) - (w[.triceps]! / w[.pectorals]!) * chest) < 1e-9)
        #expect(abs((stim[.deltoids] ?? 0) - (w[.deltoids]! / w[.pectorals]!) * chest) < 1e-9)
        // The assistors receive strictly less stimulus than the prime mover.
        #expect((stim[.triceps] ?? 0) < chest)
    }

    /// The development model and the volume bars share ONE work
    /// currency: a strength session's stimulus equals `muscleVolume`'s
    /// effective sets for the same window, muscle for muscle.
    @Test func stimulusMatchesMuscleVolumeCurrency() {
        let s = session(at: day(0), [
            lift("Bench Press", .chest, sets: 3, reps: 10, weight: 135),
            lift("Back Squat", .legs, sets: 4, reps: 5, weight: 225),
        ])
        let stim = MuscleDevelopment.sessionStimulus(s)
        let stats = [s].muscleVolume(now: day(0))
        for stat in stats {
            #expect(abs(stat.effectiveSets - (stim[stat.muscle] ?? 0)) < 1e-9)
        }
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

        let a = oneStep.fibers[.pectorals]!.weeklyVolume
        let b = manySteps.fibers[.pectorals]!.weeklyVolume
        #expect(abs(a - b) < 1e-9)
    }

    /// Same history in, same channels out.
    @Test func simulationIsDeterministic() {
        let program = benchProgram(sessions: 10, everyDays: 3.5)
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
        let program = benchProgram(sessions: 8, everyDays: 3.5)
        let now = program.last!.completedAt!
        let forward = MuscleDevelopment.simulate(from: program, now: now).adaptation(.pectorals)
        let shuffled = MuscleDevelopment.simulate(from: program.reversed(), now: now).adaptation(.pectorals)
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

    @Test func gluteMaxAndMedPaintIndependently() {
        let extensionSession = session(
            at: day(0),
            [lift("Barbell Hip Thrust", .legs, sets: 3, reps: 10, weight: 185)]
        )
        let extensionNodes = MuscleDevelopment.nodeIntensities(from: [extensionSession], now: day(0))
        #expect((extensionNodes["Gluteus_Maximus_L"] ?? 0) > 0)
        #expect(extensionNodes["Gluteus_Medius_L"] == nil)

        let abductionSession = session(
            at: day(0),
            [lift("Machine Hip Abduction", .legs, sets: 3, reps: 15, weight: 90)]
        )
        let abductionNodes = MuscleDevelopment.nodeIntensities(from: [abductionSession], now: day(0))
        #expect((abductionNodes["Gluteus_Medius_L"] ?? 0) > 0)
        #expect(abductionNodes["Gluteus_Maximus_L"] == nil)
    }

    // MARK: - Colour mapping

    @Test(arguments: [BodyModelTheme.dark, .light])
    func developmentDeepensTheOrange(theme: BodyModelTheme) {
        // Less developed = the theme's muted clay/stone base; more
        // developed = a vivid, saturated orange. The ramp sweeps a
        // wide arc — red rises while green + blue drain (chroma
        // climbs) — so mid-range differences between muscles read,
        // and the developed tone stays clearly orange (r > g > b),
        // never crushed into brown.
        let pale = MuscleColor.rgb(for: .init(adaptation: 0.1), theme: theme)
        let vivid = MuscleColor.rgb(for: .init(adaptation: 0.95), theme: theme)
        #expect(vivid.green < pale.green)
        #expect(vivid.blue < pale.blue)
        #expect(vivid.red > pale.red)
        #expect(vivid.red > vivid.green && vivid.green > vivid.blue)
        // Saturation (chroma proxy) rises with development.
        #expect((vivid.red - vivid.blue) > (pale.red - pale.blue))
    }

    @Test func rampsMoveAwayFromTheirOwnStage() {
        // Each theme's ramp must gain contrast against its own stage
        // as development climbs: on black the muscle LIGHTS UP (red
        // channel surges toward the vivid accent); on the near-white
        // page it DEEPENS (total luminance falls).
        let pale = { (t: BodyModelTheme) in
            MuscleColor.rgb(for: .init(adaptation: 0.05), theme: t)
        }
        let vivid = { (t: BodyModelTheme) in
            MuscleColor.rgb(for: .init(adaptation: 1.0), theme: t)
        }
        #expect(vivid(.dark).red - pale(.dark).red > 0.2)
        let lightPale = pale(.light), lightVivid = vivid(.light)
        #expect(
            lightVivid.red + lightVivid.green + lightVivid.blue
                < lightPale.red + lightPale.green + lightPale.blue - 0.2
        )
    }

    /// Every colour in a full development sweep stays in gamut `0...1`.
    @Test(arguments: [BodyModelTheme.dark, .light])
    func colourStaysInGamut(theme: BodyModelTheme) {
        for a in stride(from: 0.0, through: 1.0, by: 0.2) {
            let c = MuscleColor.rgb(for: .init(adaptation: a), theme: theme)
            #expect(c.red >= 0 && c.red <= 1)
            #expect(c.green >= 0 && c.green <= 1)
            #expect(c.blue >= 0 && c.blue <= 1)
        }
    }

    // MARK: - Helpers

    /// One completed, single-exercise (or multi-) session stamped at a date.
    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// A completed lift: every planned set marked done.
    private func lift(_ name: String, _ group: MuscleGroup, sets: Int, reps: Int, weight: Double) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true; $0.repsInReserve = 2 }
        return ex
    }

    /// A bench-press program: `sessions` workouts spaced `everyDays`
    /// apart at a steady per-session set count.
    private func benchProgram(sessions n: Int, everyDays: Double, sets: Int = 3) -> [WorkoutSession] {
        (0..<n).map { i in
            session(
                at: day(Double(i) * everyDays),
                [lift("Bench Press", .chest, sets: sets, reps: 8, weight: 135)]
            )
        }
    }

    /// Chest adaptation after the first `k` sessions of a program,
    /// evaluated the instant the kth session finishes (no decay).
    private func adaptation(_ muscle: Muscle, afterFirst k: Int, of program: [WorkoutSession]) -> Double {
        let subset = Array(program.prefix(k))
        guard let last = subset.last?.completedAt else { return 0 }
        return MuscleDevelopment.simulate(from: subset, now: last).adaptation(muscle)
    }
}

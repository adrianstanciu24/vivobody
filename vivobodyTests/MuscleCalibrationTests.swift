//
//  MuscleCalibrationTests.swift
//  vivobodyTests
//
//  The calibration sweep for the development model — the lesson from
//  the salmon-collapse bug, encoded. Realistic multi-week programs
//  must land in VISUALLY DISTINCT bands of the colour ramp: a
//  dedicated program clearly ahead of a casual one, primary muscles
//  clearly ahead of their assistors, and a long layoff visibly faded
//  but not erased. If a parameter change squeezes real training data
//  into one indistinguishable mid-tone, this file fails before the
//  body does.
//
//  Like every model test, it runs on a virtual clock: a 12-week
//  program is just dates.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MuscleCalibrationTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Programs

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup, sets: Int) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: 8, plannedWeight: 135)
        ex.sets.forEach { $0.isCompleted = true; $0.repsInReserve = 2 }
        return ex
    }

    /// One completed set for the hard-set honesty programs. A nil
    /// `rir` means the set was never rated (`rirLogged` false).
    private struct SetsSpec {
        var weight: Double
        var reps: Int
        var rir: Int? = nil
        var kind: WorkoutSetKind = .working
    }

    /// A completed bench press with per-set control over weight,
    /// reps, and rated RIR — the levers the hard-set currency reads.
    private func bench(_ specs: [SetsSpec]) -> Exercise {
        let ex = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: specs.count,
            plannedReps: specs.first?.reps ?? 8,
            plannedWeight: specs.first?.weight ?? 0
        )
        for (spec, set) in zip(specs, ex.orderedSets) {
            set.weight = spec.weight
            set.reps = spec.reps
            set.isCompleted = true
            set.kind = spec.kind
            if let rir = spec.rir {
                set.repsInReserve = rir
                set.rirLogged = true
            }
        }
        return ex
    }

    /// A bench program at a chosen weekly frequency and per-session
    /// set count, running `weeks` weeks. The dose levers volume only —
    /// exactly what the model reads.
    private func benchProgram(timesPerWeek: Double, sets: Int, weeks: Int) -> [WorkoutSession] {
        let gap = 7.0 / timesPerWeek
        let count = Int(Double(weeks) * timesPerWeek)
        return (0..<count).map { i in
            session(at: day(Double(i) * gap), [lift("Bench Press", .chest, sets: sets)])
        }
    }

    private func chest(_ sessions: [WorkoutSession], at date: Date) -> Double {
        MuscleDevelopment.simulate(from: sessions, now: date).adaptation(.pectorals)
    }

    // MARK: - Distinct bands

    /// Twelve weeks of dedicated training (2×/week, 6 sets) must read
    /// clearly ahead of twelve casual weeks (1×/week, 3 sets) — and
    /// both must sit in the visible middle of the ramp, not crushed
    /// together at either end.
    @Test func dedicatedAndCasualProgramsLandInDistinctBands() {
        let dedicated = benchProgram(timesPerWeek: 2, sets: 6, weeks: 12)
        let casual = benchProgram(timesPerWeek: 1, sets: 3, weeks: 12)

        let strong = chest(dedicated, at: dedicated.last!.completedAt!)
        let light = chest(casual, at: casual.last!.completedAt!)

        #expect(strong > light + 0.15)        // clearly distinguishable
        #expect(strong > 0.55 && strong < 0.8) // well-developed, still climbing
        #expect(light > 0.2 && light < 0.5)    // visible, but clearly behind
    }

    /// Primary muscles must separate from their assistors: a bench-only
    /// block lights the chest clearly ahead of the front delts, which
    /// only collect fractional credit.
    @Test func primeMoversSeparateFromAssistors() {
        let program = benchProgram(timesPerWeek: 2, sets: 6, weeks: 12)
        let state = MuscleDevelopment.simulate(from: program, now: program.last!.completedAt!)

        let chest = state.adaptation(.pectorals)
        let delts = state.adaptation(.deltoids)

        #expect(delts > 0)                    // assistor credit registers
        #expect(chest > delts + 0.1)          // ...but reads clearly dimmer
        #expect(state.adaptation(.quads) == 0) // untouched stays dark
    }

    // MARK: - Hard-set honesty (load / reps / RIR currency)

    /// Same set count, different substance: 12 weeks of 3 working
    /// sets + 3 warm-up ramps must land visibly below 12 weeks of 6
    /// working sets. The raw-count currency read these as identical.
    @Test func warmupPaddingReadsBelowWorkingVolume() {
        func program(warmups: Bool) -> [WorkoutSession] {
            (0..<24).map { i in
                let working = SetsSpec(weight: 135, reps: 8)
                let warmup = SetsSpec(weight: 55, reps: 8)
                let plan = warmups
                    ? [warmup, warmup, warmup, working, working, working]
                    : [working, working, working, working, working, working]
                return session(at: day(Double(i) * 3.5), [bench(plan)])
            }
        }
        let padded = program(warmups: true)
        let honest = program(warmups: false)

        let a = chest(padded, at: padded.last!.completedAt!)
        let b = chest(honest, at: honest.last!.completedAt!)

        #expect(b > a + 0.05)   // visibly apart on the ramp
        #expect(a > 0.4)        // the working half still reads as real training
    }

    /// Explicit warm-ups are audit rows, not discounted work. Adding
    /// any number of them to the same program must leave development
    /// exactly where the working sets put it.
    @Test func explicitWarmupsDoNotMoveDevelopment() {
        func program(includeWarmups: Bool) -> [WorkoutSession] {
            (0..<24).map { i in
                let working = SetsSpec(weight: 135, reps: 8)
                let warmup = SetsSpec(weight: 55, reps: 8, kind: .warmUp)
                let plan = includeWarmups
                    ? [warmup, warmup, warmup, working, working, working]
                    : [working, working, working]
                return session(at: day(Double(i) * 3.5), [bench(plan)])
            }
        }
        let padded = program(includeWarmups: true)
        let workingOnly = program(includeWarmups: false)
        let a = chest(padded, at: padded.last!.completedAt!)
        let b = chest(workingOnly, at: workingOnly.last!.completedAt!)
        #expect(abs(a - b) < 1e-9)
    }

    /// Token weights against established strength: after four honest
    /// weeks, dropping to ~10% of demonstrated e1RM must read clearly
    /// below staying at working weight.
    @Test func tokenWeightBlockReadsBelowWorkingWeight() {
        func block(thenWeight: Double) -> [WorkoutSession] {
            (0..<24).map { i in
                let weight = i < 8 ? 135.0 : thenWeight
                return session(at: day(Double(i) * 3.5), [bench(Array(
                    repeating: SetsSpec(weight: weight, reps: 8), count: 6
                ))])
            }
        }
        let token = block(thenWeight: 15)
        let working = block(thenWeight: 135)

        let a = chest(token, at: token.last!.completedAt!)
        let b = chest(working, at: working.last!.completedAt!)

        #expect(b > a + 0.1)
        #expect(a > 0.2)        // floored, faded — but not erased
    }

    /// Effort honesty: the same program logged at RIR 5 (nowhere near
    /// failure) must read visibly below RIR 1.
    @Test func farFromFailureReadsBelowHardTraining() {
        func program(rir: Int) -> [WorkoutSession] {
            (0..<24).map { i in
                session(at: day(Double(i) * 3.5), [bench(Array(
                    repeating: SetsSpec(weight: 135, reps: 8, rir: rir), count: 6
                ))])
            }
        }
        let lazy = program(rir: 5)
        let hard = program(rir: 1)

        let a = chest(lazy, at: lazy.last!.completedAt!)
        let b = chest(hard, at: hard.last!.completedAt!)

        #expect(b > a + 0.1)
        #expect(a > 0.3)        // still real training, just dimmer
    }

    // MARK: - Fade schedule

    /// The detraining arc end-to-end: a week off keeps essentially all
    /// the colour, twelve weeks off visibly fades it, and even then a
    /// long-trained muscle isn't erased back to nothing.
    @Test func neglectFadesOnSchedule() {
        let program = benchProgram(timesPerWeek: 2, sets: 6, weeks: 12)
        let last = program.last!.completedAt!

        let fresh = chest(program, at: last)
        let oneWeekOff = chest(program, at: last.addingTimeInterval(7 * 86_400))
        let twelveWeeksOff = chest(program, at: last.addingTimeInterval(84 * 86_400))

        #expect(oneWeekOff > 0.93 * fresh)        // the grace window (~95% kept)
        #expect(twelveWeeksOff < 0.65 * fresh)    // visibly faded
        #expect(twelveWeeksOff > 0.2 * fresh)     // but not erased
    }
}

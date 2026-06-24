//
//  MuscleCalibrationTests.swift
//  vivobodyTests
//
//  The calibration sweep for the development model — the lesson from
//  the salmon-collapse bug, encoded. Realistic multi-week programs
//  must land in VISUALLY DISTINCT bands of the colour ramp: a
//  dedicated program clearly ahead of a casual one, prime movers
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

    /// Prime movers must separate from their assistors: a bench-only
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

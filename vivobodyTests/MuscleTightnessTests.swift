//
//  MuscleTightnessTests.swift
//  vivobodyTests
//
//  Exercises the tightness channel of `MuscleDevelopment` — the fourth
//  muscle state that contraction-biased loading accrues, mobility /
//  full-ROM work pays down, and rest only partly eases. Like its
//  sibling `MuscleDevelopmentTests`, it drives the model with a virtual
//  clock so weeks-long behaviour (a layoff flooring above zero) is a
//  one-liner.
//
//  The suites:
//    • Accrual    — loading tightens susceptible muscles; full-ROM
//                   compounds tighten less than isolation work.
//    • Relief     — mobility work loosens; an untrained muscle has
//                   nothing to relieve.
//    • Rest       — passive easing drops tightness but floors above
//                   zero (only active lengthening fully resolves it).
//    • Mobility    — stretching feeds relief, not growth.
//    • Catalog    — movement type resolves by name.
//

import Foundation
import Testing
@testable import vivobody

struct MuscleTightnessTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Accrual

    /// A contraction-biased loading program on the chest leaves the
    /// pectorals measurably tight.
    @Test func loadingTightensSusceptibleMuscle() {
        let program = (0..<6).map { i in
            session(at: day(Double(i) * 3), [lift("Bench Press", .chest, sets: 3, reps: 8, weight: 135)])
        }
        let last = program.last!.completedAt!
        let tightness = MuscleDevelopment.simulate(from: program, now: last)
            .fibers[.pectorals]?.tightness ?? 0
        #expect(tightness > 0.05)
    }

    /// A full-ROM compound (front squat) loads the quads through a long
    /// range and tightens them LESS than an isolation lift (leg
    /// extension) at the same tonnage.
    @Test func fullRomTightensLessThanIsolation() {
        func quadTightness(_ name: String) -> Double {
            let s = session(at: day(0), [lift(name, .legs, sets: 3, reps: 10, weight: 100)])
            return MuscleDevelopment.simulate(from: [s], now: day(0)).fibers[.quads]?.tightness ?? 0
        }
        let squat = quadTightness("Front Squats")
        let extension_ = quadTightness("Leg Extension")
        #expect(squat > 0)
        #expect(extension_ > 0)
        #expect(squat < extension_)
    }

    /// Crossed-syndrome coupling: pressing without ever training the
    /// antagonist (rows) tightens the chest MORE than the same pressing
    /// balanced by back work, because the neglected rhomboids let the
    /// pecs shorten into rounded shoulders.
    @Test func neglectedAntagonistAmplifiesTightness() {
        func pecTightness(withRows: Bool) -> Double {
            let program = (0..<6).map { i -> WorkoutSession in
                var exercises = [lift("Bench Press", .chest, sets: 3, reps: 8, weight: 135)]
                if withRows {
                    exercises.append(lift("Bent Over Rowing", .back, sets: 3, reps: 8, weight: 115))
                }
                return session(at: day(Double(i) * 3), exercises)
            }
            return MuscleDevelopment.simulate(from: program, now: program.last!.completedAt!)
                .fibers[.pectorals]?.tightness ?? 0
        }
        let neglected = pecTightness(withRows: false)
        let balanced = pecTightness(withRows: true)
        #expect(neglected > 0)
        #expect(balanced < neglected)
    }

    /// A phasic muscle (rhomboids) barely tightens compared with a
    /// tonic one (pectorals) under comparable loading.
    @Test func tonicMusclesTightenMoreThanPhasic() {
        // Both worked by the bench press; pectorals are a prime mover
        // and far more tightness-prone than the lightly-loaded delts.
        let s = session(at: day(0), [lift("Bench Press", .chest, sets: 4, reps: 8, weight: 135)])
        let state = MuscleDevelopment.simulate(from: [s], now: day(0))
        let chest = state.fibers[.pectorals]?.tightness ?? 0
        let delts = state.fibers[.deltoids]?.tightness ?? 0
        #expect(chest > delts)
    }

    // MARK: - Relief

    /// A mobility stretch on a muscle loosens the tightness loading
    /// built up there: the same history WITH a chest stretch leaves the
    /// pectorals looser than without.
    @Test func mobilityRelievesTightness() {
        let loading = (0..<6).map { i in
            session(at: day(Double(i) * 3), [lift("Bench Press", .chest, sets: 3, reps: 8, weight: 135)])
        }
        let stretchDay = loading.last!.completedAt!.addingTimeInterval(0.5 * 86_400)
        let stretchSession = session(at: stretchDay, [stretch("Doorway Pectoral Stretch", .chest, sets: 3, seconds: 30)])
        let now = stretchDay.addingTimeInterval(0.5 * 86_400)

        let withoutStretch = MuscleDevelopment.simulate(from: loading, now: now)
            .fibers[.pectorals]?.tightness ?? 0
        let withStretch = MuscleDevelopment.simulate(from: loading + [stretchSession], now: now)
            .fibers[.pectorals]?.tightness ?? 0

        #expect(withoutStretch > 0)
        #expect(withStretch < withoutStretch)
    }

    /// Stretching a muscle that was never loaded is a no-op — there is
    /// no tightness debt to pay down, and no fiber is created.
    @Test func stretchingUntrainedMuscleDoesNothing() {
        let s = session(at: day(0), [stretch("Doorway Pectoral Stretch", .chest, sets: 3, seconds: 30)])
        let state = MuscleDevelopment.simulate(from: [s], now: day(0))
        #expect((state.fibers[.pectorals]?.tightness ?? 0) == 0)
    }

    // MARK: - Rest

    /// Passive rest eases tightness but never fully clears it — a long
    /// layoff lands below the fresh value yet still strictly above
    /// zero, the signal that mobility is still owed.
    @Test func restEasesButFloorsAboveZero() {
        let program = (0..<6).map { i in
            session(at: day(Double(i) * 3), [lift("Bench Press", .chest, sets: 3, reps: 8, weight: 135)])
        }
        let last = program.last!.completedAt!

        func chestTightness(daysAfter d: Double) -> Double {
            MuscleDevelopment.simulate(from: program, now: last.addingTimeInterval(d * 86_400))
                .fibers[.pectorals]?.tightness ?? 0
        }

        let fresh = chestTightness(daysAfter: 0)
        let later = chestTightness(daysAfter: 180)
        #expect(fresh > 0)
        #expect(later < fresh)
        #expect(later > 0)
    }

    // MARK: - Mobility feeds relief, not growth

    /// A session of pure mobility work develops nothing — it lengthens
    /// rather than loads, so it must not move the adaptation channel.
    @Test func mobilityDoesNotGrowMuscle() {
        let s = session(at: day(0), [stretch("Doorway Pectoral Stretch", .chest, sets: 3, seconds: 30)])
        let state = MuscleDevelopment.simulate(from: [s], now: day(0))
        #expect((state.fibers[.pectorals]?.adaptation ?? 0) == 0)
        #expect(state.intensities.isEmpty)
    }

    // MARK: - Node channels carry tightness

    /// Tightness reaches the node-keyed channel map both `_L`/`_R`
    /// meshes read for the strain rim.
    @Test func nodeChannelsCarryTightness() {
        let program = (0..<6).map { i in
            session(at: day(Double(i) * 3), [lift("Bench Press", .chest, sets: 3, reps: 8, weight: 135)])
        }
        let nodes = MuscleDevelopment.nodeChannels(from: program, now: program.last!.completedAt!)
        #expect((nodes["Pectoralis_Major_L"]?.tightness ?? 0) > 0)
        #expect((nodes["Pectoralis_Major_R"]?.tightness ?? 0) > 0)
    }

    // MARK: - Surfacing (boards / readiness)

    /// The per-muscle board lists only flagged muscles, tightest
    /// first, and is empty for an untrained history.
    @Test func tightnessBoardListsTightMusclesDescending() {
        let program = (0..<8).map { i in
            session(at: day(Double(i) * 3), [lift("Bench Press", .chest, sets: 4, reps: 8, weight: 135)])
        }
        let board = program.muscleTightness(now: program.last!.completedAt!)
        #expect(board.hasTight)
        #expect(board.readings.contains { $0.muscle == .pectorals })
        let values = board.readings.map(\.tightness)
        #expect(values == values.sorted(by: >))
        #expect(values.allSatisfy { $0 >= MuscleTightnessBoard.threshold })

        let none: [WorkoutSession] = []
        #expect(!none.muscleTightness().hasTight)
    }

    /// Body readiness rolls tightness up to the group and flags a
    /// tightened group in its `tight` bucket.
    @Test func readinessFlagsTightGroup() {
        let program = (0..<8).map { i in
            session(at: day(Double(i) * 3), [lift("Bench Press", .chest, sets: 4, reps: 8, weight: 135)])
        }
        let readiness = program.bodyReadiness(now: program.last!.completedAt!)
        #expect(readiness.tight.contains { $0.group == .chest })
    }

    // MARK: - Catalog

    @Test func movementTypeResolvesFromCatalog() {
        #expect(MovementType.forExerciseNamed("Doorway Pectoral Stretch") == .mobility)
        #expect(MovementType.forExerciseNamed("Bench Press") == .strength)
        // Unknown / user-created names default to strength.
        #expect(MovementType.forExerciseNamed("Totally Made Up Lift") == .strength)
    }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// A completed rep-based lift: every planned set marked done.
    private func lift(_ name: String, _ group: MuscleGroup, sets: Int, reps: Int, weight: Double, rir: Int = 2) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true; $0.repsInReserve = rir }
        return ex
    }

    /// A completed timed mobility hold: every planned set marked done
    /// at the given duration.
    private func stretch(_ name: String, _ group: MuscleGroup, sets: Int, seconds: TimeInterval) -> Exercise {
        let ex = Exercise(
            name: name, group: group,
            plannedSets: sets, plannedReps: 1, plannedWeight: 0,
            trackingMode: .duration, plannedDuration: seconds
        )
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }
}

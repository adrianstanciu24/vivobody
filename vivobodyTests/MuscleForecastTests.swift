//
//  MuscleForecastTests.swift
//  vivobodyTests
//
//  Guards the forward-looking "Forecast" board. It marches the
//  development model's decay into the future, so — like the model it
//  projects — it's tested on a virtual clock: a freshly trained
//  muscle keeps a long runway through its grace window, a stale one
//  is already at risk and surfaces sooner, the projection only ever
//  decays, undeveloped muscles stay off the board, and an empty
//  archive yields nothing.
//

import Foundation
import Testing
@testable import vivobody

struct MuscleForecastTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup, weight: Double) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 3, plannedReps: 8, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    /// One movement logged on each listed day, load climbing by `step`
    /// lb per session so the muscle accrues real development.
    private func program(
        _ name: String,
        _ group: MuscleGroup,
        on days: [Double],
        startWeight: Double,
        step: Double = 5
    ) -> [WorkoutSession] {
        days.enumerated().map { i, d in
            session(at: day(d), [lift(name, group, weight: startWeight + Double(i) * step)])
        }
    }

    // MARK: - Runway ordering

    @Test func recentlyTrainedKeepsLongerRunwayThanStale() {
        // Chest is trained right up to "now"; legs stopped 8 days ago.
        let chest = program("Bench Press", .chest, on: [0, 3, 6, 9, 12], startWeight: 135)
        let legs = program("Back Squat", .legs, on: [0, 2, 4], startWeight: 185)
        let board = (chest + legs).muscleForecast(now: day(12))

        let pecs = board.stat(for: .pectorals)
        let quads = board.stat(for: .quads)
        #expect(pecs != nil)
        #expect(quads != nil)
        #expect((pecs?.daysUntilFade ?? 0) > (quads?.daysUntilFade ?? 0))
    }

    // MARK: - Grace window

    @Test func freshMuscleHoldsThroughGrace() {
        let chest = program("Bench Press", .chest, on: [0, 3, 6, 9, 12], startWeight: 135)
        let board = chest.muscleForecast(now: day(12))

        // Trained today: the grace window protects it for several days
        // before any noticeable fade.
        let pecs = board.stat(for: .pectorals)
        #expect((pecs?.daysUntilFade ?? 0) >= 4)
    }

    // MARK: - Urgency

    @Test func staleMuscleFadesSoonAndFlagsUrgent() {
        let chest = program("Bench Press", .chest, on: [0, 3, 6, 9], startWeight: 135)
        // Two weeks past the last session — well past grace.
        let board = chest.muscleForecast(now: day(9 + 14))

        let pecs = board.stat(for: .pectorals)
        #expect(pecs != nil)
        #expect((pecs?.daysUntilFade ?? .max) <= MuscleForecastBoard.urgentDays)
        #expect(board.isUrgent)
    }

    // MARK: - Projection direction

    @Test func projectionOnlyDecays() {
        let chest = program("Bench Press", .chest, on: [0, 3, 6, 9, 12], startWeight: 135)
        let board = chest.muscleForecast(now: day(12))

        for stat in board.ranked {
            #expect(stat.projectedAdaptation <= stat.currentAdaptation + 1e-9)
            #expect(stat.projectedLoss >= 0)
        }
    }

    // MARK: - Ordering

    @Test func rankedSortedSoonestFirst() {
        let chest = program("Bench Press", .chest, on: [0, 2, 4], startWeight: 135)
        let legs = program("Back Squat", .legs, on: [0, 3, 6, 9, 12], startWeight: 185)
        let back = program("Barbell Row", .back, on: [0, 5], startWeight: 135)
        let board = (chest + legs + back).muscleForecast(now: day(14))

        let days = board.ranked.map(\.daysUntilFade)
        #expect(days == days.sorted())
        #expect(board.soonestFadeDays == days.first)
    }

    // MARK: - Exclusion

    @Test func undevelopedMuscleIsAbsent() {
        let chest = program("Bench Press", .chest, on: [0, 3, 6, 9], startWeight: 135)
        let board = chest.muscleForecast(now: day(9))

        // Legs are never trained by a bench-only program.
        #expect(board.stat(for: .quads) == nil)
        #expect(!board.ranked.contains { $0.muscle == .quads })
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNoForecast() {
        let board = [WorkoutSession]().muscleForecast(now: day(0))
        #expect(!board.hasDeveloped)
        #expect(board.ranked.isEmpty)
        #expect(board.soonestFadeDays == nil)
        #expect(!board.isUrgent)
    }
}

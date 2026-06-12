//
//  MuscleMomentumTests.swift
//  vivobodyTests
//
//  Guards the trend-bucketing behind the Insights "Momentum" board.
//  Like the development model it projects, the behaviour is time-
//  driven, so it's tested on a virtual clock: a building program
//  reads as growing, a program matured to the level its volume
//  sustains settles into holding, a layoff slides into fading, and
//  undeveloped muscles stay off the board entirely.
//

import Foundation
import Testing
@testable import vivobody

struct MuscleMomentumTests {

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

    /// A bench program: `n` sessions `everyDays` apart at a steady
    /// per-session set count.
    private func benchProgram(sessions n: Int, everyDays: Double) -> [WorkoutSession] {
        (0..<n).map { i in
            session(at: day(Double(i) * everyDays),
                    [lift("Bench Press", .chest, weight: 135)])
        }
    }

    // MARK: - Growing

    @Test func buildingProgramReadsGrowing() {
        let program = benchProgram(sessions: 12, everyDays: 3.5)
        let now = program.last!.completedAt!
        let board = program.muscleMomentum(now: now)

        let chest = board.stat(for: .pectorals)
        #expect(chest?.trend == .growing)
        #expect((chest?.momentum ?? 0) > MuscleMomentumBoard.growingThreshold)
        #expect(board.growing.contains { $0.muscle == .pectorals })
    }

    // MARK: - Holding

    @Test func maturedProgramReadsHolding() {
        // A steady cadence eventually carries the accumulator to the
        // level that volume sustains: the slow tracker catches the
        // fast one and momentum settles inside the holding band.
        // Growth also visibly cools on the way there.
        let early = benchProgram(sessions: 12, everyDays: 3.5)
        let matured = benchProgram(sessions: 156, everyDays: 3.5)

        let earlyMomentum = early.muscleMomentum(now: early.last!.completedAt!)
            .stat(for: .pectorals)?.momentum ?? 0
        let board = matured.muscleMomentum(now: matured.last!.completedAt!)
        let chest = board.stat(for: .pectorals)

        #expect((chest?.momentum ?? 1) < earlyMomentum)
        #expect(chest?.trend == .holding)
        #expect(abs(chest?.momentum ?? 1) <= MuscleMomentumBoard.growingThreshold)
    }

    // MARK: - Fading

    @Test func layoffReadsFading() {
        let program = benchProgram(sessions: 12, everyDays: 3.5)
        let last = program.last!.completedAt!
        // Well past the ~1-week grace: the fast channel has dropped
        // below the slow tracker, so momentum is clearly negative.
        let board = program.muscleMomentum(now: last.addingTimeInterval(45 * 86_400))

        let chest = board.stat(for: .pectorals)
        #expect(chest?.trend == .fading)
        #expect((chest?.momentum ?? 0) < MuscleMomentumBoard.fadingThreshold)
        // Still developed enough to remain on the board.
        #expect((chest?.adaptation ?? 0) >= MuscleMomentumBoard.developmentFloor)
    }

    // MARK: - Exclusion

    @Test func untrainedMuscleIsAbsentFromBoard() {
        let program = benchProgram(sessions: 8, everyDays: 3.5)
        let now = program.last!.completedAt!
        let board = program.muscleMomentum(now: now)

        // Legs are never touched by a bench-only program — no fiber,
        // so they never appear on the board.
        #expect(board.stat(for: .quads) == nil)
        #expect(!board.growing.contains { $0.muscle == .quads })
        #expect(!board.holding.contains { $0.muscle == .quads })
        #expect(!board.fading.contains { $0.muscle == .quads })
    }

    // MARK: - Empty

    @Test func emptyArchiveHasEmptyBoard() {
        let board = [WorkoutSession]().muscleMomentum(now: day(0))
        #expect(!board.hasAny)
        #expect(board.growingCount == 0)
        #expect(board.holdingCount == 0)
        #expect(board.fadingCount == 0)
    }

    // MARK: - Partition integrity

    @Test func bucketsPartitionByTrend() {
        let program = benchProgram(sessions: 12, everyDays: 3.5)
        let board = program.muscleMomentum(now: program.last!.completedAt!)
        #expect(board.growing.allSatisfy { $0.trend == .growing })
        #expect(board.holding.allSatisfy { $0.trend == .holding })
        #expect(board.fading.allSatisfy { $0.trend == .fading })
    }
}

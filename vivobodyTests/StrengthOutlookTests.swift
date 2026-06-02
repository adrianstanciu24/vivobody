//
//  StrengthOutlookTests.swift
//  vivobodyTests
//
//  Guards the strength-trend engine behind the Insights "Strength"
//  section. It fits a line to each lift's estimated-1RM history, so
//  it's tested on a virtual clock: progressive overload sets a fresh
//  PR and reads climbing; a lift grinding back toward an old record
//  projects a days-to-PR; a flat program plateaus; a descending one
//  slips; bodyweight and too-thin histories are excluded.
//

import Foundation
import Testing
@testable import vivobody

struct StrengthOutlookTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup, weight: Double, reps: Int = 5) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 1, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    /// One session per weight, `everyDays` apart, starting at day 0.
    private func series(_ name: String, _ group: MuscleGroup, weights: [Double], everyDays: Double = 4, reps: Int = 5) -> [WorkoutSession] {
        weights.enumerated().map { i, w in
            session(at: day(Double(i) * everyDays), [lift(name, group, weight: w, reps: reps)])
        }
    }

    private func now(after sessions: [WorkoutSession]) -> Date {
        sessions.map { $0.completedAt! }.max()!
    }

    // MARK: - Climbing / fresh PR

    @Test func progressiveOverloadSetsFreshPR() {
        let s = series("Bench Press", .chest, weights: [135, 140, 145, 150, 155])
        let board = s.strengthOutlook(now: now(after: s))

        let bench = board.stat(for: "Bench Press")
        #expect(bench?.trend == .climbing)
        #expect(bench?.isFreshPR == true)
        // Just set the record — no projection needed.
        #expect(bench?.daysToPR == nil)
        #expect((bench?.slopePerWeek ?? 0) > 0)
    }

    // MARK: - Climbing back → projected PR

    @Test func grindingBackProjectsDaysToPR() {
        // An old record, then a block climbing back up but not yet there.
        let s = series("Back Squat", .legs, weights: [255, 205, 215, 225, 235, 245, 250])
        let board = s.strengthOutlook(now: now(after: s))

        let squat = board.stat(for: "Back Squat")
        #expect(squat?.trend == .climbing)
        #expect(squat?.isFreshPR == false)
        // Below the old best, climbing → a finite ETA within horizon.
        if let days = squat?.daysToPR {
            #expect(days >= 1)
            #expect(days <= StrengthOutlookBoard.horizonDays)
        } else {
            Issue.record("expected a projected days-to-PR")
        }
    }

    // MARK: - Plateau

    @Test func flatProgramPlateaus() {
        let s = series("Overhead Press", .shoulders, weights: [95, 95, 95, 95, 95, 95])
        let board = s.strengthOutlook(now: now(after: s))

        let ohp = board.stat(for: "Overhead Press")
        #expect(ohp?.trend == .plateaued)
        #expect(ohp?.isFreshPR == false)
        #expect(ohp?.daysToPR == nil)
    }

    // MARK: - Slipping

    @Test func descendingProgramSlips() {
        let s = series("Deadlift", .back, weights: [405, 395, 385, 375, 365])
        let board = s.strengthOutlook(now: now(after: s))

        let dl = board.stat(for: "Deadlift")
        #expect(dl?.trend == .slipping)
        #expect((dl?.slopePerWeek ?? 0) < 0)
        #expect(dl?.daysToPR == nil)
    }

    // MARK: - Exclusions

    @Test func tooFewPointsExcluded() {
        let s = series("Bench Press", .chest, weights: [135, 140])
        let board = s.strengthOutlook(now: now(after: s))
        #expect(board.stat(for: "Bench Press") == nil)
    }

    @Test func bodyweightLiftExcluded() {
        // Zero logged weight → estimated 1RM is zero → no strength curve.
        let s = series("Pull-Up", .back, weights: [0, 0, 0, 0])
        let board = s.strengthOutlook(now: now(after: s))
        #expect(board.stat(for: "Pull-Up") == nil)
    }

    @Test func emptyArchiveEmptyBoard() {
        let board = [WorkoutSession]().strengthOutlook(now: day(0))
        #expect(!board.hasAny)
        #expect(board.stats.isEmpty)
        #expect(board.nearestPR == nil)
    }

    // MARK: - Ranking

    @Test func climbingRanksAheadOfSlipping() {
        let climbing = series("Bench Press", .chest, weights: [135, 140, 145, 150, 155])
        let slipping = series("Deadlift", .back, weights: [405, 395, 385, 375, 365])
        let all = climbing + slipping
        let board = all.strengthOutlook(now: now(after: all))

        #expect(board.stats.first?.exercise == "Bench Press")
        #expect(board.nearestPR?.exercise == "Bench Press")
        #expect(board.climbingCount == 1)
        #expect(board.slippingCount == 1)
    }
}

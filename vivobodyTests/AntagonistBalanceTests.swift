//
//  AntagonistBalanceTests.swift
//  vivobodyTests
//
//  Guards the Insights "Symmetry" board. The verdict math is a pure
//  share calculation (tested directly), and the aggregation is graded
//  effective-set volume over a window (tested on a virtual clock):
//  a press-only block flags the pull side, adding rows pulls the
//  split back toward even, squats skew quad-dominant, pairs without
//  enough work drop off, and an empty archive yields nothing.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct AntagonistBalanceTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Helpers

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup, sets: Int = 4) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: sets, plannedReps: 8, plannedWeight: 100)
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    // MARK: - Verdict math (pure)

    @Test func verdictMath() {
        let even = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 10, rightSets: 10)
        #expect(even.verdict == .balanced)
        #expect(abs(even.leftShare - 0.5) < 1e-9)
        #expect(abs(even.skew) < 1e-9)

        let leftHeavy = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 24, rightSets: 8)
        #expect(leftHeavy.verdict == .leftHeavy)
        #expect(leftHeavy.heavierLabel == "A")
        #expect(leftHeavy.lighterLabel == "B")

        let rightHeavy = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 5, rightSets: 20)
        #expect(rightHeavy.verdict == .rightHeavy)
        #expect(rightHeavy.heavierLabel == "B")

        // Just inside the ±10% tolerance band still reads balanced.
        let edge = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 11, rightSets: 9)
        #expect(edge.verdict == .balanced)
    }

    // MARK: - Press-only flags the pull side

    @Test func pressOnlyFlagsPull() {
        let s = (0..<4).map { i in
            session(at: day(Double(i) * 5), [lift("Bench Press", .chest), lift("Overhead Press", .shoulders)])
        }
        let board = s.antagonistBalance(now: day(20))

        let pushPull = board.pair("push-pull")
        #expect(pushPull != nil)
        #expect(pushPull?.verdict == .leftHeavy)        // push outweighs pull
        #expect(pushPull?.heavierLabel == "Push")
        #expect(pushPull?.lighterLabel == "Pull")
        // Press-only leaves several pairs lopsided (the arms most of
        // all, since biceps get no work) — at minimum, something flags.
        #expect(board.imbalancedCount >= 1)
        #expect(board.worst != nil)
    }

    // MARK: - Adding pulls restores balance

    @Test func addingPullsReducesSkew() {
        let pressOnly = (0..<4).map { i in
            session(at: day(Double(i) * 5), [lift("Bench Press", .chest)])
        }
        let mixed = (0..<4).map { i in
            session(at: day(Double(i) * 5), [lift("Bench Press", .chest), lift("Bent Over Rowing", .back)])
        }

        let skewPress = pressOnly.antagonistBalance(now: day(20)).pair("push-pull")!.skew
        let skewMixed = mixed.antagonistBalance(now: day(20)).pair("push-pull")!.skew
        #expect(skewMixed < skewPress)
    }

    // MARK: - Squats skew quad-dominant

    @Test func squatsSkewQuadDominant() {
        let s = (0..<4).map { i in
            session(at: day(Double(i) * 5), [lift("Squats", .legs)])
        }
        let board = s.antagonistBalance(now: day(20))

        let quadHam = board.pair("quad-ham")
        #expect(quadHam != nil)
        #expect(quadHam?.heavierLabel == "Quads")
        #expect((quadHam?.leftShare ?? 0) > 0.5)
    }

    // MARK: - Pairs without work are dropped

    @Test func untouchedPairDropped() {
        // Bench works chest/tri/delts but never the legs.
        let s = (0..<4).map { i in
            session(at: day(Double(i) * 5), [lift("Bench Press", .chest)])
        }
        let board = s.antagonistBalance(now: day(20))

        #expect(board.pair("quad-ham") == nil)   // no leg work at all
        #expect(board.pair("push-pull") != nil)  // pressing still registers
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNoPairs() {
        let board = [WorkoutSession]().antagonistBalance(now: day(0))
        #expect(!board.hasAny)
        #expect(board.pairs.isEmpty)
        #expect(board.worst == nil)
    }
}

//
//  AntagonistBalanceTests.swift
//  vivobodyTests
//
//  Guards the Insights "Symmetry" board. It covers verdict math,
//  role-based muscle comparisons, whole-exercise movement comparisons,
//  directional isolation, squat/hinge filtering, laterality counting,
//  chronological hard-set pricing, and the 28-day/future boundaries
//  on a virtual clock.
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

    private func lift(
        _ name: String,
        _ group: MuscleGroup,
        sets: Int = 4,
        weight: Double = 100
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            group: group,
            plannedSets: sets,
            plannedReps: 8,
            plannedWeight: weight
        )
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    private func expectEqual(
        _ actual: Double?,
        _ expected: Double,
        tolerance: Double = 1e-9
    ) {
        #expect(actual != nil)
        #expect(abs((actual ?? 0) - expected) < tolerance)
    }

    // MARK: - Verdict math (pure)

    @Test func verdictMath() {
        let even = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 10, rightSets: 10)
        #expect(even.verdict == .balanced)
        #expect(abs(even.leftShare - 0.5) < 1e-9)
        #expect(abs(even.skew) < 1e-9)

        let empty = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 0, rightSets: 0)
        #expect(empty.verdict == .noData)
        #expect(!empty.hasMeaningfulWork)
        #expect(!empty.isBalanced)

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
            session(at: day(Double(i) * 5), [lift("Bench Press", .chest), lift("Shoulder Press, Dumbbells", .shoulders)])
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

    // MARK: - New comparisons

    @Test func directionalPushPullPairsCountWholeExerciseStimulus() {
        let board = [
            session(at: day(1), [
                lift("Bench Press", .chest, sets: 2),
                lift("Bent Over Rowing", .back, sets: 3),
                lift("Shoulder Press, Dumbbells", .shoulders, sets: 4),
                lift("Lat Pull Down", .back, sets: 5),
            ]),
        ].antagonistBalance(now: day(2))

        let horizontal = board.pair("horizontal-push-pull")
        expectEqual(horizontal?.leftSets, 2)
        expectEqual(horizontal?.rightSets, 3)

        let vertical = board.pair("vertical-push-pull")
        expectEqual(vertical?.leftSets, 4)
        expectEqual(vertical?.rightSets, 5)
    }

    @Test func directionsDoNotLeakIntoEachOther() {
        let horizontalOnly = [
            session(at: day(1), [
                lift("Bench Press", .chest),
                lift("Bent Over Rowing", .back),
            ]),
        ].antagonistBalance(now: day(2))
        #expect(horizontalOnly.pair("horizontal-push-pull") != nil)
        expectEqual(horizontalOnly.pair("vertical-push-pull")?.leftSets, 0)
        expectEqual(horizontalOnly.pair("vertical-push-pull")?.rightSets, 0)
        #expect(horizontalOnly.pair("vertical-push-pull")?.verdict == .noData)

        let verticalOnly = [
            session(at: day(1), [
                lift("Shoulder Press, Dumbbells", .shoulders),
                lift("Lat Pull Down", .back),
            ]),
        ].antagonistBalance(now: day(2))
        expectEqual(verticalOnly.pair("horizontal-push-pull")?.leftSets, 0)
        expectEqual(verticalOnly.pair("horizontal-push-pull")?.rightSets, 0)
        #expect(verticalOnly.pair("horizontal-push-pull")?.verdict == .noData)
        #expect(verticalOnly.pair("vertical-push-pull") != nil)
    }

    @Test func hipAndLowerLegPairsKeepGradedMuscleCredit() {
        let board = [
            session(at: day(1), [
                lift("Clamshell", .legs, sets: 2),
                lift("Copenhagen Adduction Exercise", .legs, sets: 3),
                lift("Standing Calf Raises", .legs, sets: 4),
                lift("Tibialis raises", .legs, sets: 5),
            ]),
        ].antagonistBalance(now: day(2))

        let hip = board.pair("hip-abductors-adductors")
        expectEqual(hip?.leftSets, 2)
        expectEqual(hip?.rightSets, 3)

        let lowerLeg = board.pair("calves-shins")
        expectEqual(lowerLeg?.leftSets, 4)
        expectEqual(lowerLeg?.rightSets, 5)
    }

    @Test func squatHingeExcludesLungesAndOtherPatterns() {
        let board = [
            session(at: day(1), [
                lift("Squats", .legs, sets: 2),
                lift("Barbell Romanian Deadlift (RDL)", .legs, sets: 3),
                lift("Dumbbell Lunges Walking", .legs, sets: 6),
                lift("Bench Press", .chest, sets: 7),
            ]),
        ].antagonistBalance(now: day(2))

        let pair = board.pair("squat-hinge")
        expectEqual(pair?.leftSets, 2)
        expectEqual(pair?.rightSets, 3)
    }

    @Test func unilateralExercisesAreNotDoubled() {
        let board = [
            session(at: day(1), [
                lift("Bench Press", .chest, sets: 2),
                lift("One Arm Bent Row", .back, sets: 3),
            ]),
        ].antagonistBalance(now: day(2))

        let pair = board.pair("bilateral-unilateral")
        expectEqual(pair?.leftSets, 2)
        expectEqual(pair?.rightSets, 3)
    }

    @Test func unknownClassificationIsExcludedFromMovementPairs() {
        let board = [
            session(at: day(1), [
                lift("My Custom Press", .chest, sets: 4),
            ]),
        ].antagonistBalance(now: day(2))

        #expect(board.pair("push-pull") != nil)
        #expect(board.pair("horizontal-push-pull")?.verdict == .noData)
        #expect(board.pair("vertical-push-pull")?.verdict == .noData)
        #expect(board.pair("squat-hinge")?.verdict == .noData)
        #expect(board.pair("bilateral-unilateral")?.verdict == .noData)
    }

    @Test func displayOrderIsDeterministicAndGrouped() {
        let board = [
            session(at: day(1), [
                lift("Bench Press", .chest),
                lift("Bent Over Rowing", .back),
                lift("Shoulder Press, Dumbbells", .shoulders),
                lift("Lat Pull Down", .back),
                lift("Squats", .legs),
                lift("Barbell Romanian Deadlift (RDL)", .legs),
                lift("Clamshell", .legs),
                lift("Copenhagen Adduction Exercise", .legs),
                lift("Standing Calf Raises", .legs),
                lift("Tibialis raises", .legs),
                lift("One Arm Bent Row", .back),
            ]),
        ].antagonistBalance(now: day(2))

        #expect(board.pairs.map(\.id) == [
            "push-pull",
            "horizontal-push-pull",
            "vertical-push-pull",
            "bi-tri",
            "quad-ham",
            "hip-abductors-adductors",
            "calves-shins",
            "squat-hinge",
            "bilateral-unilateral",
        ])
    }

    // MARK: - Causality and time boundaries

    @Test func chronologicalReplayPricesMovementStimulusCausally() {
        let heavy = session(
            at: day(0),
            [lift("Bench Press", .chest, sets: 1, weight: 300)]
        )
        let light = session(
            at: day(10),
            [lift("Bench Press", .chest, sets: 4, weight: 100)]
        )

        let chronological = [heavy, light].antagonistBalance(now: day(30))
        let reversed = [light, heavy].antagonistBalance(now: day(30))
        let first = chronological.pair("horizontal-push-pull")?.leftSets
        let second = reversed.pair("horizontal-push-pull")?.leftSets

        #expect(first != nil)
        #expect((first ?? 4) < 4)
        expectEqual(second, first ?? 0)
    }

    @Test func respectsWindowAndExcludesFutureSessions() {
        let old = session(
            at: day(0),
            [lift("Bench Press", .chest, sets: 2, weight: 300)]
        )
        let recent = session(
            at: day(30),
            [lift("Bench Press", .chest, sets: 4, weight: 100)]
        )
        let future = session(
            at: day(41),
            [lift("Shoulder Press, Dumbbells", .shoulders, sets: 4)]
        )
        let board = [future, recent, old].antagonistBalance(now: day(40))

        let horizontal = board.pair("horizontal-push-pull")
        #expect(horizontal != nil)
        #expect((horizontal?.leftSets ?? 4) < 4)
        #expect(horizontal?.rightSets == 0)
        #expect(board.pair("vertical-push-pull")?.verdict == .noData)
    }

    @Test func sessionAnalyticsForwardsInjectedNow() {
        let analytics = SessionAnalytics()
        let recent = session(
            at: day(39),
            [lift("Bench Press", .chest, sets: 2)]
        )

        analytics.update(for: [recent], now: day(40))

        #expect(analytics.symmetry.pair("horizontal-push-pull") != nil)
    }

    // MARK: - Pairs without work remain visible

    @Test func untouchedPairRemainsWithNoData() {
        // Bench works chest/tri/delts but never the legs.
        let s = (0..<4).map { i in
            session(at: day(Double(i) * 5), [lift("Bench Press", .chest)])
        }
        let board = s.antagonistBalance(now: day(20))

        let quadHam = board.pair("quad-ham")
        expectEqual(quadHam?.leftSets, 0)
        expectEqual(quadHam?.rightSets, 0)
        #expect(quadHam?.verdict == .noData)
        #expect(board.pair("push-pull")?.hasMeaningfulWork == true)
    }

    // MARK: - Empty

    @Test func emptyArchiveHasAllPairsWithNoData() {
        let board = [WorkoutSession]().antagonistBalance(now: day(0))
        #expect(!board.hasAny)
        #expect(board.pairs.map(\.id) == [
            "push-pull",
            "horizontal-push-pull",
            "vertical-push-pull",
            "bi-tri",
            "quad-ham",
            "hip-abductors-adductors",
            "calves-shins",
            "squat-hinge",
            "bilateral-unilateral",
        ])
        #expect(board.pairs.allSatisfy { $0.leftSets == 0 })
        #expect(board.pairs.allSatisfy { $0.rightSets == 0 })
        #expect(board.pairs.allSatisfy { $0.verdict == .noData })
        #expect(board.imbalancedCount == 0)
        #expect(board.worst == nil)
    }
}

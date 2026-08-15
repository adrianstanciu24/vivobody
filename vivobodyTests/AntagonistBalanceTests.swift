//
//  AntagonistBalanceTests.swift
//  vivobodyTests
//
//  Guards the Insights "Symmetry" board. It covers verdict math,
//  role-based muscle comparisons, whole-exercise movement comparisons,
//  mechanic-separated and directional push/pull, squat/hinge filtering,
//  laterality counting,
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
    private func day(_ n: Double) -> Date {
        Self.origin.addingTimeInterval(n * 86400)
    }

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

        let tiny = AntagonistPair(id: "x", leftLabel: "A", rightLabel: "B", leftSets: 1, rightSets: 1)
        #expect(tiny.verdict == .noData)

        let oneWorkout = AntagonistPair(
            id: "x",
            leftLabel: "A",
            rightLabel: "B",
            leftSets: 10,
            rightSets: 10,
            sampleSessions: 1
        )
        #expect(oneWorkout.verdict == .noData)

        let descriptive = AntagonistPair(
            id: "style",
            leftLabel: "A",
            rightLabel: "B",
            leftSets: 10,
            rightSets: 10,
            comparisonKind: .distribution
        )
        #expect(descriptive.isDescriptive)
    }

    // MARK: - Press-only flags the pull side

    @Test func pressOnlyFlagsPull() {
        let s = (0 ..< 4).map { i in
            session(at: day(Double(i) * 5), [
                lift("Barbell Bench Press", .chest),
                lift("Standing Dumbbell Overhead Press", .shoulders),
            ])
        }
        let board = s.antagonistBalance(now: day(20))

        let pushPull = board.pair("compound-push-pull")
        #expect(pushPull != nil)
        #expect(pushPull?.verdict == .leftHeavy) // push outweighs pull
        #expect(pushPull?.heavierLabel == "Compound Push")
        #expect(pushPull?.lighterLabel == "Compound Pull")
        // Press-only leaves several pairs lopsided (the arms most of
        // all, since biceps get no work) — at minimum, something flags.
        #expect(board.imbalancedCount >= 1)
        #expect(board.worst != nil)
    }

    // MARK: - Adding pulls restores balance

    @Test func addingPullsReducesSkew() throws {
        let pressOnly = (0 ..< 4).map { i in
            session(at: day(Double(i) * 5), [lift("Barbell Bench Press", .chest)])
        }
        let mixed = (0 ..< 4).map { i in
            session(at: day(Double(i) * 5), [
                lift("Barbell Bench Press", .chest),
                lift("Barbell Bent-Over Row", .back),
            ])
        }

        let skewPress = try #require(pressOnly.antagonistBalance(now: day(20)).pair("compound-push-pull")?.skew)
        let skewMixed = try #require(mixed.antagonistBalance(now: day(20)).pair("compound-push-pull")?.skew)
        #expect(skewMixed < skewPress)
    }

    // MARK: - Squats skew quad-dominant

    @Test func squatsSkewQuadDominant() {
        let s = (0 ..< 4).map { i in
            session(at: day(Double(i) * 5), [lift("Barbell Back Squat", .legs)])
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
                lift("Barbell Bench Press", .chest, sets: 2),
                lift("Barbell Bent-Over Row", .back, sets: 3),
                lift("Standing Dumbbell Overhead Press", .shoulders, sets: 4),
                lift("Cable Lat Pulldown", .back, sets: 5),
            ]),
        ].antagonistBalance(now: day(2))

        let horizontal = board.pair("horizontal-push-pull")
        expectEqual(horizontal?.leftSets, 2)
        expectEqual(horizontal?.rightSets, 3)

        let vertical = board.pair("vertical-push-pull")
        expectEqual(vertical?.leftSets, 4)
        expectEqual(vertical?.rightSets, 5)

        // The broad comparison now uses the same whole-exercise
        // currency instead of summing a different number of muscles
        // on each side.
        let broad = board.pair("compound-push-pull")
        expectEqual(broad?.leftSets, 6)
        expectEqual(broad?.rightSets, 8)
    }

    @Test func compoundAndIsolationPushPullNeverLeakAcrossBuckets() {
        let board = [
            session(at: day(1), [
                lift("Barbell Bench Press", .chest, sets: 2),
                lift("Barbell Bent-Over Row", .back, sets: 3),
                lift("Single-Arm Pronated Cable Triceps Pushdown", .arms, sets: 4),
                lift("Supinated Straight-Bar Cable Curl", .arms, sets: 5),
            ]),
        ].antagonistBalance(now: day(2))

        let compound = board.pair("compound-push-pull")
        expectEqual(compound?.leftSets, 2)
        expectEqual(compound?.rightSets, 3)

        let isolation = board.pair("isolation-push-pull")
        expectEqual(isolation?.leftSets, 4)
        expectEqual(isolation?.rightSets, 5)
        #expect(isolation?.comparisonKind == .distribution)
    }

    @Test func isolationPushPullUnlocksAcrossMultipleSessions() {
        let board = [1.0, 5.0].map { sessionDay in
            session(at: day(sessionDay), [
                lift("Single-Arm Pronated Cable Triceps Pushdown", .arms, sets: 2),
                lift("Supinated Straight-Bar Cable Curl", .arms, sets: 2),
            ])
        }.antagonistBalance(now: day(6))

        let isolation = board.pair("isolation-push-pull")
        expectEqual(isolation?.leftSets, 4)
        expectEqual(isolation?.rightSets, 4)
        #expect(isolation?.sampleSessions == 2)
        #expect(isolation?.hasMeaningfulWork == true)
        #expect(isolation?.isDescriptive == true)
    }

    @Test func legacyCompoundRoleRemainsCountedWithoutReclassifyingIsolation() {
        func legacyExercise(
            mechanic: Mechanic,
            pattern: MovementPattern?,
            direction: PushPullDirection?
        ) -> Exercise {
            let exercise = Exercise(
                name: "Legacy Snapshot",
                group: .chest,
                plannedSets: 3,
                plannedReps: 8,
                plannedWeight: 100,
                classification: ExerciseClassification(
                    equipment: .cable,
                    mechanic: mechanic,
                    pattern: pattern,
                    direction: direction,
                    planes: [.sagittal],
                    laterality: .bilateral
                )
            )
            exercise.sets.forEach { $0.isCompleted = true }
            return exercise
        }

        let board = [
            session(at: day(1), [
                legacyExercise(mechanic: .compound, pattern: .push, direction: .horizontal),
                legacyExercise(mechanic: .isolation, pattern: nil, direction: nil),
            ]),
        ].antagonistBalance(now: day(2))

        expectEqual(board.pair("compound-push-pull")?.leftSets, 3)
        expectEqual(board.pair("isolation-push-pull")?.leftSets, 0)
        expectEqual(board.pair("isolation-push-pull")?.rightSets, 0)
    }

    @Test func uprightRowCountsAsReviewedVerticalPull() {
        let board = [
            session(at: day(1), [
                lift("Standing Low-Cable Upright Row", .shoulders, sets: 3),
            ]),
        ].antagonistBalance(now: day(2))

        expectEqual(board.pair("compound-push-pull")?.leftSets, 0)
        expectEqual(board.pair("compound-push-pull")?.rightSets, 3)
        expectEqual(board.pair("vertical-push-pull")?.leftSets, 0)
        expectEqual(board.pair("vertical-push-pull")?.rightSets, 3)
        expectEqual(board.pair("horizontal-push-pull")?.rightSets, 0)
    }

    @Test func nonstandardPressBranchesKeepReviewedDirectionalOwnership() {
        let board = [
            session(at: day(1), [
                lift("Standing Single-Arm Landmine Press Power Test", .shoulders, sets: 3),
                lift("Wall-Supported Strict Handstand Push-Up", .shoulders, sets: 4),
            ]),
        ].antagonistBalance(now: day(2))

        expectEqual(board.pair("compound-push-pull")?.leftSets, 7)
        expectEqual(board.pair("horizontal-push-pull")?.leftSets, 3)
        expectEqual(board.pair("vertical-push-pull")?.leftSets, 4)
    }

    @Test func directionsDoNotLeakIntoEachOther() {
        let horizontalOnly = [
            session(at: day(1), [
                lift("Barbell Bench Press", .chest),
                lift("Barbell Bent-Over Row", .back),
            ]),
        ].antagonistBalance(now: day(2))
        #expect(horizontalOnly.pair("horizontal-push-pull") != nil)
        expectEqual(horizontalOnly.pair("vertical-push-pull")?.leftSets, 0)
        expectEqual(horizontalOnly.pair("vertical-push-pull")?.rightSets, 0)
        #expect(horizontalOnly.pair("vertical-push-pull")?.verdict == .noData)

        let verticalOnly = [
            session(at: day(1), [
                lift("Standing Dumbbell Overhead Press", .shoulders),
                lift("Cable Lat Pulldown", .back),
            ]),
        ].antagonistBalance(now: day(2))
        expectEqual(verticalOnly.pair("horizontal-push-pull")?.leftSets, 0)
        expectEqual(verticalOnly.pair("horizontal-push-pull")?.rightSets, 0)
        #expect(verticalOnly.pair("horizontal-push-pull")?.verdict == .noData)
        #expect(verticalOnly.pair("vertical-push-pull") != nil)
    }

    @Test func diagonalBenchPressesJoinHorizontalAncestry() {
        let board = [
            session(at: day(1), [
                lift("Incline Barbell Bench Press", .chest, sets: 4),
                lift("Decline Dumbbell Bench Press", .chest, sets: 3),
            ]),
        ].antagonistBalance(now: day(2))

        expectEqual(board.pair("compound-push-pull")?.leftSets, 7)
        let directional = board.pair("horizontal-push-pull")
        expectEqual(directional?.leftSets, 7)
        #expect(directional?.leftLabel == "Horizontal + Diagonal Push")
        expectEqual(board.pair("vertical-push-pull")?.leftSets, 0)
    }

    @Test func diagonalPullCountsBroadlyWithoutInventingDirectionalAncestry() {
        let board = [
            session(at: day(1), [
                lift("Seated 45-Degree Cable Pulldown", .back, sets: 3),
            ]),
        ].antagonistBalance(now: day(2))

        expectEqual(board.pair("compound-push-pull")?.leftSets, 0)
        expectEqual(board.pair("compound-push-pull")?.rightSets, 3)
        expectEqual(board.pair("horizontal-push-pull")?.rightSets, 0)
        expectEqual(board.pair("vertical-push-pull")?.rightSets, 0)
    }

    @Test func hipAndLowerLegPairsKeepGradedMuscleCredit() {
        let board = [
            session(at: day(1), [
                lift("Pressure-Biofeedback Side-Lying Hip Abduction", .legs, sets: 2),
                lift("Supported Standing Band Hip Adduction", .legs, sets: 3),
                lift("Standing Unilateral Machine Calf Raise", .legs, sets: 4),
                lift("Seated Band Ankle Dorsiflexion", .legs, sets: 5),
            ]),
        ].antagonistBalance(now: day(2))

        let hip = board.pair("hip-abductors-adductors")
        expectEqual(hip?.leftSets, 2)
        expectEqual(hip?.rightSets, 3)
        #expect(hip?.comparisonKind == .distribution)

        let lowerLeg = board.pair("calves-shins")
        expectEqual(lowerLeg?.leftSets, 4)
        expectEqual(lowerLeg?.rightSets, 5)
        #expect(lowerLeg?.comparisonKind == .distribution)
    }

    @Test func rosterLimitedPairsNeverDriveAnImbalanceVerdict() {
        let sessions = (0 ..< 2).map { index in
            session(at: day(Double(index) * 5), [
                lift("Pressure-Biofeedback Side-Lying Hip Abduction", .legs, sets: 3),
                lift("Standing Unilateral Machine Calf Raise", .legs, sets: 3),
            ])
        }
        let board = sessions.antagonistBalance(now: day(10))

        let hip = board.pair("hip-abductors-adductors")
        #expect(hip?.hasMeaningfulWork == true)
        #expect(hip?.isDescriptive == true)

        let lowerLeg = board.pair("calves-shins")
        #expect(lowerLeg?.hasMeaningfulWork == true)
        #expect(lowerLeg?.isDescriptive == true)

        #expect(board.imbalancedCount == 0)
        #expect(board.worst == nil)
    }

    @Test func squatHingeExcludesLungesAndOtherPatterns() {
        let board = [
            session(at: day(1), [
                lift("Barbell Back Squat", .legs, sets: 2),
                lift("25% Body-Mass Barbell Good Morning", .legs, sets: 3),
                lift("Barbell Split Squat", .legs, sets: 6),
                lift("Bodyweight Forward Lunge", .legs, sets: 7),
                lift("Bodyweight Reverse Lunge", .legs, sets: 8),
                lift("Barbell Bench Press", .chest, sets: 7),
            ]),
        ].antagonistBalance(now: day(2))

        let pair = board.pair("squat-hinge")
        expectEqual(pair?.leftSets, 2)
        expectEqual(pair?.rightSets, 3)
    }

    @Test func unilateralExercisesAreNotDoubled() {
        let board = [
            session(at: day(1), [
                lift("Barbell Bench Press", .chest, sets: 2),
                lift("One-Arm Dumbbell Row", .back, sets: 3),
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

        #expect(board.pair("compound-push-pull") != nil)
        #expect(board.pair("horizontal-push-pull")?.verdict == .noData)
        #expect(board.pair("vertical-push-pull")?.verdict == .noData)
        #expect(board.pair("squat-hinge")?.verdict == .noData)
        #expect(board.pair("bilateral-unilateral")?.verdict == .noData)
    }

    @Test func displayOrderIsDeterministicAndGrouped() {
        let board = [
            session(at: day(1), [
                lift("Barbell Bench Press", .chest),
                lift("Barbell Bent-Over Row", .back),
                lift("Standing Dumbbell Overhead Press", .shoulders),
                lift("Cable Lat Pulldown", .back),
                lift("Barbell Back Squat", .legs),
                lift("Barbell Hip Thrust", .legs),
                lift("Pressure-Biofeedback Side-Lying Hip Abduction", .legs),
                lift("Supported Standing Band Hip Adduction", .legs),
                lift("Standing Unilateral Machine Calf Raise", .legs),
                lift("Seated Band Ankle Dorsiflexion", .legs),
                lift("One-Arm Dumbbell Row", .back),
            ]),
        ].antagonistBalance(now: day(2))

        #expect(board.pairs.map(\.id) == [
            "compound-push-pull",
            "horizontal-push-pull",
            "vertical-push-pull",
            "isolation-push-pull",
            "bi-tri",
            "quad-ham",
            "hip-abductors-adductors",
            "calves-shins",
            "squat-hinge",
            "bilateral-unilateral",
        ])
    }

    // MARK: - Causality and time boundaries

    @Test func chronologicalReplayLeavesUnloggedRIRUndiscounted() {
        let heavy = session(
            at: day(0),
            [lift("Barbell Bench Press", .chest, sets: 1, weight: 300)]
        )
        let light = session(
            at: day(10),
            [lift("Barbell Bench Press", .chest, sets: 4, weight: 100)]
        )

        let chronological = [heavy, light].antagonistBalance(now: day(30))
        let reversed = [light, heavy].antagonistBalance(now: day(30))
        let first = chronological.pair("horizontal-push-pull")?.leftSets
        let second = reversed.pair("horizontal-push-pull")?.leftSets

        // Load alone does not discount set equivalents. Without logged
        // RIR, all four completed sets retain full movement credit.
        expectEqual(first, 4)
        expectEqual(second, 4)
    }

    @Test func respectsWindowAndExcludesFutureSessions() {
        let old = session(
            at: day(0),
            [lift("Barbell Bench Press", .chest, sets: 2, weight: 300)]
        )
        let recent = session(
            at: day(30),
            [lift("Barbell Bench Press", .chest, sets: 4, weight: 100)]
        )
        let future = session(
            at: day(41),
            [lift("Standing Dumbbell Overhead Press", .shoulders, sets: 4)]
        )
        let board = [future, recent, old].antagonistBalance(now: day(40))

        let horizontal = board.pair("horizontal-push-pull")
        #expect(horizontal != nil)
        expectEqual(horizontal?.leftSets, 4)
        #expect(horizontal?.rightSets == 0)
        #expect(board.pair("vertical-push-pull")?.verdict == .noData)
    }

    @Test func sessionAnalyticsForwardsInjectedNow() async {
        let analytics = SessionAnalytics()
        let recent = session(
            at: day(39),
            [lift("Barbell Bench Press", .chest, sets: 2)]
        )

        analytics.requestInsights(for: [recent], now: day(40))
        await analytics.waitForPendingWork()

        #expect(analytics.symmetry.pair("horizontal-push-pull") != nil)
    }

    // MARK: - Pairs without work remain visible

    @Test func untouchedPairRemainsWithNoData() {
        // Bench works chest/tri/delts but never the legs.
        let s = (0 ..< 4).map { i in
            session(at: day(Double(i) * 5), [lift("Barbell Bench Press", .chest)])
        }
        let board = s.antagonistBalance(now: day(20))

        let quadHam = board.pair("quad-ham")
        expectEqual(quadHam?.leftSets, 0)
        expectEqual(quadHam?.rightSets, 0)
        #expect(quadHam?.verdict == .noData)
        #expect(board.pair("compound-push-pull")?.hasMeaningfulWork == true)
    }

    // MARK: - Empty

    @Test func emptyArchiveHasAllPairsWithNoData() {
        let board = [WorkoutSession]().antagonistBalance(now: day(0))
        #expect(!board.hasAny)
        #expect(board.pairs.map(\.id) == [
            "compound-push-pull",
            "horizontal-push-pull",
            "vertical-push-pull",
            "isolation-push-pull",
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

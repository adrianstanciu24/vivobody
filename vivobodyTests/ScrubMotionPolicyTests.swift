//
//  ScrubMotionPolicyTests.swift
//  vivobodyTests
//
//  Locks BareScrubber's pure axis, detent, wall, rubber-band, and coast rules.
//

import CoreGraphics
import Foundation
import Testing
@testable import vivobody

struct ScrubMotionPolicyTests {
    private let standard = ScrubMotionConfiguration(
        range: 0 ... 100,
        step: 1,
        pointsPerStep: 10
    )

    private func update(
        x: CGFloat = 0,
        y: CGFloat,
        value: Double = 50,
        state: ScrubDragState = ScrubDragState(),
        configuration: ScrubMotionConfiguration? = nil
    ) -> ScrubDragUpdate {
        ScrubMotionPolicy.dragUpdate(
            horizontalTranslation: x,
            verticalTranslation: y,
            currentValue: value,
            state: state,
            configuration: configuration ?? standard
        )
    }

    @Test func axisClaimRequiresEightPointsAndGivesTiesToVertical() {
        let undecided = update(x: 7.999, y: 7.999)
        #expect(undecided.state.axisClaim == .undecided)
        #expect(undecided.adjustment == nil)

        let horizontal = update(x: 8, y: 0)
        #expect(horizontal.state.axisClaim == .horizontal)
        #expect(horizontal.adjustment == nil)

        let tied = update(x: 8, y: 8)
        #expect(tied.state.axisClaim == .vertical(baselineY: 8))
        #expect(tied.beganVerticalDrag)
        #expect(tied.adjustment?.value == 50)
    }

    @Test func axisClaimIsStickyAndUsesTheFixedSignedBaseline() {
        let positive = update(y: 30)
        #expect(positive.state.axisClaim == .vertical(baselineY: 8))
        #expect(positive.adjustment?.value == 48)

        let stillVertical = update(
            x: 100,
            y: 18,
            value: 48,
            state: positive.state
        )
        #expect(stillVertical.state.axisClaim == .vertical(baselineY: 8))
        #expect(stillVertical.beganVerticalDrag == false)
        #expect(stillVertical.adjustment?.value == 49)

        let negative = update(y: -28)
        #expect(negative.state.axisClaim == .vertical(baselineY: -8))
        #expect(negative.adjustment?.value == 52)

        let horizontal = update(x: 9, y: 8)
        let remainsHorizontal = update(y: 40, state: horizontal.state)
        #expect(remainsHorizontal.state.axisClaim == .horizontal)
        #expect(remainsHorizontal.adjustment == nil)
    }

    @Test func deadBandAndNearestDetentMatchTheFingerContract() {
        #expect(update(y: 8).adjustment?.value == 50)
        #expect(update(y: -8).adjustment?.value == 50)
        #expect(update(y: 13).adjustment?.value == 49)
        #expect(update(y: -13).adjustment?.value == 51)
        #expect(update(y: -28).adjustment?.value == 52)
    }

    @Test func eachDragEventEmitsAtMostOneDetentAcrossSkipsAndReversals() {
        let first = update(y: -48)
        #expect(first.adjustment?.value == 54)
        #expect(first.adjustment?.feedback == [.detent])

        let skipped = update(y: -68, value: 54, state: first.state)
        #expect(skipped.adjustment?.value == 56)
        #expect(skipped.adjustment?.feedback == [.detent])

        let repeated = update(y: -68, value: 56, state: skipped.state)
        #expect(repeated.adjustment?.feedback.isEmpty == true)

        let reversed = update(y: -28, value: 56, state: repeated.state)
        #expect(reversed.adjustment?.value == 52)
        #expect(reversed.adjustment?.feedback == [.detent])
    }

    @Test func rangeEndpointsAreInsideAndStrictOvershootHitsTheWallFirst() {
        let configuration = ScrubMotionConfiguration(
            range: 0 ... 10,
            step: 1,
            pointsPerStep: 10
        )

        let exactMaximum = update(y: -58, value: 5, configuration: configuration)
        #expect(exactMaximum.adjustment?.value == 10)
        #expect(exactMaximum.adjustment?.feedback == [.detent])

        let beyondMaximum = update(y: -68, value: 5, configuration: configuration)
        #expect(beyondMaximum.adjustment?.value == 10)
        #expect(beyondMaximum.adjustment?.feedback == [.wall(.maximum), .detent])

        let exactMinimum = update(y: 58, value: 5, configuration: configuration)
        #expect(exactMinimum.adjustment?.value == 0)
        #expect(exactMinimum.adjustment?.feedback == [.detent])

        let beyondMinimum = update(y: 68, value: 5, configuration: configuration)
        #expect(beyondMinimum.adjustment?.value == 0)
        #expect(beyondMinimum.adjustment?.feedback == [.wall(.minimum), .detent])
    }

    @Test func wallFeedbackLatchesUntilTheDragReturnsInside() {
        let configuration = ScrubMotionConfiguration(
            range: 0 ... 10,
            step: 1,
            pointsPerStep: 10
        )
        let firstWall = update(y: -28, value: 9, configuration: configuration)
        #expect(firstWall.adjustment?.feedback == [.wall(.maximum), .detent])

        let heldBeyond = update(
            y: -28,
            value: 10,
            state: firstWall.state,
            configuration: configuration
        )
        #expect(heldBeyond.adjustment?.feedback.isEmpty == true)

        let endpoint = update(
            y: -18,
            value: 10,
            state: heldBeyond.state,
            configuration: configuration
        )
        #expect(endpoint.adjustment?.feedback.isEmpty == true)
        #expect(endpoint.state.didHitMaximumWall == false)

        let secondWall = update(
            y: -28,
            value: 10,
            state: endpoint.state,
            configuration: configuration
        )
        #expect(secondWall.adjustment?.feedback == [.wall(.maximum)])
    }

    @Test func rubberBandUsesTheBoundedAsymptoticCurve() {
        #expect(ScrubMotionPolicy.rubberBandDistance(0) == 0)
        #expect(abs(ScrubMotionPolicy.rubberBandDistance(10) - 8.333_333_333) < 0.000_001)
        #expect(abs(ScrubMotionPolicy.rubberBandDistance(20) - 14.285_714_286) < 0.000_001)
        #expect(ScrubMotionPolicy.rubberBandDistance(50) == 25)
        #expect(ScrubMotionPolicy.rubberBandDistance(150) == 37.5)
        #expect(ScrubMotionPolicy.rubberBandDistance(10000) < 50)
    }

    @Test func wallOffsetsHaveDirectionAndOffGridClampDoesNotInventADetent() {
        let minimum = update(y: 28, value: 0)
        #expect((minimum.adjustment?.rubberOffset ?? 0) > 0)
        #expect(minimum.adjustment?.feedback == [.wall(.minimum)])

        let maximum = update(y: -28, value: 100)
        #expect((maximum.adjustment?.rubberOffset ?? 0) < 0)
        #expect(maximum.adjustment?.feedback == [.wall(.maximum)])

        let offGrid = update(
            y: -18,
            value: 99,
            configuration: ScrubMotionConfiguration(
                range: 0 ... 100,
                step: 5,
                pointsPerStep: 10
            )
        )
        #expect(offGrid.adjustment?.value == 100)
        #expect(offGrid.adjustment?.feedback == [.wall(.maximum)])
        #expect(offGrid.state.lastReportedDetent == 0)
    }

    @Test func coastRequiresAQuickEnabledMotionPermittingFlick() {
        let accepted = ScrubMotionPolicy.coastPlan(
            momentumPoints: -50,
            touchDuration: 0.3,
            isEnabled: true,
            reduceMotion: false,
            configuration: standard
        )
        #expect(accepted?.detentCount == 2)

        #expect(coast(momentum: -50, duration: 0.300_001) == nil)
        #expect(coast(momentum: -50, isEnabled: false) == nil)
        #expect(coast(momentum: -50, reduceMotion: true) == nil)
        #expect(coast(momentum: -30) == nil)
    }

    @Test func coastProjectionRoundsAwayAtTiesAndCapsAtTwentyFour() {
        #expect(ScrubMotionPolicy.projectedDetents(momentumPoints: -50, pointsPerStep: 9) == 3)
        #expect(ScrubMotionPolicy.projectedDetents(momentumPoints: 50, pointsPerStep: 9) == -3)
        #expect(coast(momentum: -1000)?.direction == .increase)
        #expect(coast(momentum: -1000)?.detentCount == 24)
        #expect(coast(momentum: 1000)?.direction == .decrease)
        #expect(coast(momentum: 1000)?.detentCount == 24)
    }

    @Test func coastScheduleDecaysFromTwentyEightToOneHundredFortyMilliseconds() throws {
        let two = try #require(coast(momentum: -50)?.intervals)
        #expect(two.count == 2)
        #expect(abs(two[0] - 0.028) < 0.000_000_001)
        #expect(abs(two[1] - 0.14) < 0.000_000_001)

        let three = try #require(coast(momentum: -60)?.intervals)
        #expect(three.count == 3)
        #expect(abs(three[0] - 0.028) < 0.000_000_001)
        #expect(abs(three[1] - 0.062_609_903) < 0.000_000_001)
        #expect(abs(three[2] - 0.14) < 0.000_000_001)

        let capped = try #require(coast(momentum: -1000)?.intervals)
        #expect(capped.count == 24)
        #expect(zip(capped, capped.dropFirst()).allSatisfy { $0.0 < $0.1 })
        #expect(try abs(#require(capped.last) - 0.14) < 0.000_000_001)
    }

    @Test func coastPartiallyClampsBeforeTheFollowingStepHitsItsWall() {
        let configuration = ScrubMotionConfiguration(
            range: 0 ... 100,
            step: 5,
            pointsPerStep: 10
        )
        let partial = ScrubMotionPolicy.coastStep(
            from: 99,
            direction: .increase,
            configuration: configuration
        )
        #expect(partial == .advanced(value: 100))

        let wall = ScrubMotionPolicy.coastStep(
            from: 100,
            direction: .increase,
            configuration: configuration
        )
        #expect(wall == .hitWall(.maximum))
        #expect(
            ScrubMotionPolicy.coastStep(
                from: 0,
                direction: .decrease,
                configuration: configuration
            ) == .hitWall(.minimum)
        )
    }

    @Test func clampHelperKeepsValuesInsideTheConfiguredRange() {
        #expect(standard.clamped(-1) == 0)
        #expect(standard.clamped(42.5) == 42.5)
        #expect(standard.clamped(101) == 100)
    }

    private func coast(
        momentum: CGFloat,
        duration: TimeInterval = 0.2,
        isEnabled: Bool = true,
        reduceMotion: Bool = false
    ) -> ScrubCoastPlan? {
        ScrubMotionPolicy.coastPlan(
            momentumPoints: momentum,
            touchDuration: duration,
            isEnabled: isEnabled,
            reduceMotion: reduceMotion,
            configuration: standard
        )
    }
}

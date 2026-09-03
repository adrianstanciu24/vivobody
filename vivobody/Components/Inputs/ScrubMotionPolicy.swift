//
//  ScrubMotionPolicy.swift
//  vivobody
//
//  Pure mechanics for BareScrubber axis ownership, drag detents,
//  elastic range walls, and the bounded flywheel coast.
//

import CoreGraphics
import Foundation

nonisolated struct ScrubMotionConfiguration: Equatable {
    let range: ClosedRange<Double>
    let step: Double
    let pointsPerStep: CGFloat

    func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

nonisolated enum ScrubAxisClaim: Equatable {
    case undecided
    case horizontal
    case vertical(baselineY: CGFloat)

    var isVertical: Bool {
        if case .vertical = self { return true }
        return false
    }
}

nonisolated enum ScrubWall: Equatable, Hashable {
    case minimum
    case maximum
}

nonisolated enum ScrubDirection: Equatable {
    case decrease
    case increase

    var multiplier: Double {
        self == .increase ? 1 : -1
    }

    var wall: ScrubWall {
        self == .increase ? .maximum : .minimum
    }
}

nonisolated enum ScrubFeedback: Equatable {
    case wall(ScrubWall)
    case detent
}

nonisolated struct ScrubDragState: Equatable {
    var axisClaim: ScrubAxisClaim = .undecided
    var startValue: Double = 0
    var lastReportedDetent: Int = 0
    var didHitMinimumWall = false
    var didHitMaximumWall = false
}

nonisolated struct ScrubDragAdjustment: Equatable {
    let value: Double
    let rubberOffset: CGFloat
    let feedback: [ScrubFeedback]
}

nonisolated struct ScrubDragUpdate: Equatable {
    let state: ScrubDragState
    let beganVerticalDrag: Bool
    let adjustment: ScrubDragAdjustment?
}

nonisolated struct ScrubCoastPlan: Equatable {
    let direction: ScrubDirection
    let intervals: [TimeInterval]

    var detentCount: Int {
        intervals.count
    }
}

nonisolated enum ScrubCoastOutcome: Equatable {
    case advanced(value: Double)
    case hitWall(ScrubWall)
}

nonisolated enum ScrubMotionPolicy {
    static let axisClaimDistance: CGFloat = 8
    static let flickMaxDuration: TimeInterval = 0.3

    static func dragUpdate(
        horizontalTranslation: CGFloat,
        verticalTranslation: CGFloat,
        currentValue: Double,
        state: ScrubDragState,
        configuration: ScrubMotionConfiguration
    ) -> ScrubDragUpdate {
        let resolution = resolveAxis(
            horizontalTranslation: horizontalTranslation,
            verticalTranslation: verticalTranslation,
            currentValue: currentValue,
            state: state
        )
        var nextState = resolution.state
        guard case let .vertical(baselineY) = nextState.axisClaim else {
            return ScrubDragUpdate(
                state: nextState,
                beganVerticalDrag: false,
                adjustment: nil
            )
        }

        let translationY = verticalTranslation - baselineY
        let detent = Int((-translationY / configuration.pointsPerStep).rounded())
        let proposedValue = nextState.startValue + Double(detent) * configuration.step
        let clampedValue = configuration.clamped(proposedValue)
        let inRangeDragPoints = abs(clampedValue - nextState.startValue)
            / configuration.step * configuration.pointsPerStep
        let pointsOver = max(0, abs(translationY) - inRangeDragPoints)

        var rubberOffset: CGFloat = 0
        var feedback: [ScrubFeedback] = []
        if proposedValue < configuration.range.lowerBound {
            rubberOffset = rubberBandDistance(pointsOver)
            if !nextState.didHitMinimumWall {
                feedback.append(.wall(.minimum))
                nextState.didHitMinimumWall = true
            }
        } else if proposedValue > configuration.range.upperBound {
            rubberOffset = -rubberBandDistance(pointsOver)
            if !nextState.didHitMaximumWall {
                feedback.append(.wall(.maximum))
                nextState.didHitMaximumWall = true
            }
        } else {
            nextState.didHitMinimumWall = false
            nextState.didHitMaximumWall = false
        }

        let actualDetent = Int(
            ((clampedValue - nextState.startValue) / configuration.step).rounded()
        )
        if actualDetent != nextState.lastReportedDetent {
            feedback.append(.detent)
            nextState.lastReportedDetent = actualDetent
        }

        return ScrubDragUpdate(
            state: nextState,
            beganVerticalDrag: resolution.beganVerticalDrag,
            adjustment: ScrubDragAdjustment(
                value: clampedValue,
                rubberOffset: rubberOffset,
                feedback: feedback
            )
        )
    }

    private static func resolveAxis(
        horizontalTranslation: CGFloat,
        verticalTranslation: CGFloat,
        currentValue: Double,
        state: ScrubDragState
    ) -> (state: ScrubDragState, beganVerticalDrag: Bool) {
        switch state.axisClaim {
        case .horizontal, .vertical:
            return (state, false)
        case .undecided:
            let horizontalDistance = abs(horizontalTranslation)
            let verticalDistance = abs(verticalTranslation)
            guard max(horizontalDistance, verticalDistance) >= axisClaimDistance else {
                return (state, false)
            }
            guard verticalDistance >= horizontalDistance else {
                var horizontalState = state
                horizontalState.axisClaim = .horizontal
                return (horizontalState, false)
            }
            let baselineY = verticalTranslation >= 0
                ? axisClaimDistance
                : -axisClaimDistance
            return (
                ScrubDragState(
                    axisClaim: .vertical(baselineY: baselineY),
                    startValue: currentValue,
                    lastReportedDetent: 0,
                    didHitMinimumWall: false,
                    didHitMaximumWall: false
                ),
                true
            )
        }
    }

    static func rubberBandDistance(
        _ pointsOver: CGFloat,
        maximumStretch: CGFloat = 50
    ) -> CGFloat {
        maximumStretch * (1 - 1 / (pointsOver / maximumStretch + 1))
    }

    static func coastPlan(
        momentumPoints: CGFloat,
        touchDuration: TimeInterval,
        isEnabled: Bool,
        reduceMotion: Bool,
        configuration: ScrubMotionConfiguration
    ) -> ScrubCoastPlan? {
        guard touchDuration <= flickMaxDuration, !reduceMotion, isEnabled else {
            return nil
        }

        let projected = projectedDetents(
            momentumPoints: momentumPoints,
            pointsPerStep: configuration.pointsPerStep
        )
        guard abs(projected) >= 2 else { return nil }

        let capped = max(-24, min(24, projected))
        let direction: ScrubDirection = capped > 0 ? .increase : .decrease
        let total = abs(capped)
        let growth = pow(5.0, 1.0 / Double(max(total - 1, 1)))
        var intervals: [TimeInterval] = []
        intervals.reserveCapacity(total)
        var interval: TimeInterval = 0.028
        for _ in 0 ..< total {
            intervals.append(interval)
            interval *= growth
        }
        return ScrubCoastPlan(direction: direction, intervals: intervals)
    }

    static func projectedDetents(
        momentumPoints: CGFloat,
        pointsPerStep: CGFloat
    ) -> Int {
        Int((-momentumPoints / pointsPerStep * 0.45).rounded())
    }

    static func coastStep(
        from value: Double,
        direction: ScrubDirection,
        configuration: ScrubMotionConfiguration
    ) -> ScrubCoastOutcome {
        let next = value + direction.multiplier * configuration.step
        let clamped = configuration.clamped(next)
        guard clamped != value else { return .hitWall(direction.wall) }
        return .advanced(value: clamped)
    }
}

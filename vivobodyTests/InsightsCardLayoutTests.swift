//
//  InsightsCardLayoutTests.swift
//  vivobodyTests
//
//  Pins the Insights card order, the phone column's spacing, and the wide
//  lanes: strict reading-order alternation, independent lane stacking, and
//  lanes that stay clear of the fold.
//

import CoreGraphics
import Testing
@testable import vivobody

@MainActor
struct InsightsCardLayoutTests {
    private let foldedWidth: CGFloat = 867
    private let fold = CGRect(x: 455, y: -82, width: 40, height: 669)

    @Test func nineCardsInReadingOrder() {
        #expect(InsightsCardID.allCases.map(\.rawValue) == [
            "signature", "exerciseMix", "repMix", "movementCoverage", "load",
            "stamina", "consistency", "balance", "muscleDirectness",
        ])
    }

    @Test func singleColumnKeepsTheInstrumentGroups() {
        #expect(InsightsCardID.allCases.map(\.singleColumnLeadingSpace) == [
            .none, .groupSeparator, .gap(8), .gap(16), .groupSeparator,
            .gap(20), .groupSeparator, .groupSeparator, .gap(20),
        ])
    }

    @Test func withoutAFoldTheLanesSplitTheWidthEvenly() {
        let lanes = InsightsLanes(width: foldedWidth, divisions: [])

        #expect(lanes.leading == 20 ... 417.5)
        #expect(lanes.trailing == 449.5 ... 847)
    }

    @Test func aFoldKeepsAGutterOnEachSide() {
        let lanes = InsightsLanes(width: foldedWidth, divisions: [fold])

        #expect(lanes.leading == 20 ... 435)
        #expect(lanes.trailing == 515 ... 847)
    }

    @Test func horizontalAndEdgeDivisionsDoNotSplitTheLanes() {
        let even = InsightsLanes(width: foldedWidth, divisions: [])

        #expect(InsightsLanes(
            width: foldedWidth,
            divisions: [CGRect(x: 0, y: 300, width: 867, height: 40)]
        ) == even)
        #expect(InsightsLanes(
            width: foldedWidth,
            divisions: [CGRect(x: 10, y: 0, width: 20, height: 600)]
        ) == even)
    }

    @Test func cardsAlternateByReadingOrderWhateverTheirHeights() {
        let lanes = InsightsLanes(width: foldedWidth, divisions: [fold])
        let plan = InsightsCardPlan(
            heights: [600, 80, 80, 80, 80, 80, 80, 80, 80],
            lanes: lanes,
            spacing: 32
        )

        let leadingIndices = plan.frames.indices.filter { plan.frames[$0].minX == 20 }
        let trailingIndices = plan.frames.indices.filter { plan.frames[$0].minX == 515 }
        #expect(leadingIndices == [0, 2, 4, 6, 8])
        #expect(trailingIndices == [1, 3, 5, 7])
    }

    @Test func eachLaneStacksItsOwnCards() {
        let lanes = InsightsLanes(width: foldedWidth, divisions: [fold])
        let plan = InsightsCardPlan(heights: [100, 50, 30, 200], lanes: lanes, spacing: 10)

        #expect(plan.frames.map(\.minY) == [0, 0, 110, 60])
        #expect(plan.frames.map(\.width) == [415, 332, 415, 332])
        #expect(plan.height == 260)
    }

    @Test func noCardCrossesTheFold() {
        let lanes = InsightsLanes(width: foldedWidth, divisions: [fold])
        let plan = InsightsCardPlan(
            heights: Array(repeating: 120, count: InsightsCardID.allCases.count),
            lanes: lanes,
            spacing: 32
        )

        #expect(plan.frames.count == 9)
        #expect(plan.frames.allSatisfy { $0.maxX <= fold.minX || $0.minX >= fold.maxX })
    }

    @Test func noCardsMeansNoHeight() {
        let plan = InsightsCardPlan(
            heights: [],
            lanes: InsightsLanes(width: foldedWidth, divisions: []),
            spacing: 32
        )

        #expect(plan.frames.isEmpty)
        #expect(plan.height == 0)
    }
}

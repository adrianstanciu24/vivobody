//
//  TodayHeroSizingTests.swift
//  vivobodyTests
//
//  Pins Today's figure height: the latch that keeps one size per container
//  width, the normal and accessibility formulas, and the turntable width cap
//  that keeps the figure inside a narrow pane.
//

import CoreGraphics
import Testing
@testable import vivobody

@MainActor
struct TodayHeroSizingTests {
    private func sizing(_ containers: TodayHeroSizing.Container...) -> TodayHeroSizing {
        var sizing = TodayHeroSizing()
        for container in containers {
            sizing.accept(container)
        }
        return sizing
    }

    private func container(
        _ width: CGFloat,
        _ height: CGFloat,
        topInset: CGFloat = 0
    ) -> TodayHeroSizing.Container {
        TodayHeroSizing.Container(size: CGSize(width: width, height: height), topInset: topInset)
    }

    @Test func noSizeYetMeansNoFigure() {
        #expect(TodayHeroSizing().heroHeight(accessibility: false) == 0)
        #expect(sizing(container(0, 800), container(402, 0)).heroHeight(accessibility: false) == 0)
    }

    @Test func phoneFormulaLeavesRoomForTheBarAndLegend() {
        let phone = sizing(container(402, 800))

        #expect(phone.heroHeight(accessibility: false) == 592)
        #expect(phone.heroHeight(accessibility: true) == 400)
    }

    @Test func shortContainersKeepTheMinimumShare() {
        let short = sizing(container(402, 500))

        #expect(short.heroHeight(accessibility: false) == 340)
    }

    @Test func accessibilityHeightStopsAt420() {
        #expect(sizing(container(1000, 1200)).heroHeight(accessibility: true) == 420)
    }

    @Test func aTransientShorterReadingNeverShrinksTheFigure() {
        let launched = sizing(container(402, 800), container(402, 520), container(402, 790))

        #expect(launched.containerHeight == 800)
        #expect(launched.heroHeight(accessibility: false) == 592)
    }

    @Test func withoutTheInsetTheFigureGrowsWithTheContainer() {
        let collapsed = sizing(container(402, 623), container(402, 675))

        #expect(collapsed.containerHeight == 675)
    }

    @Test func withTheInsetATitleCollapseKeepsTheExpandedHeight() {
        let collapsed = sizing(
            container(433, 553, topInset: 82),
            container(433, 611, topInset: 24),
            container(433, 553, topInset: 82)
        )

        #expect(collapsed.containerHeight == 553)
        #expect(abs(collapsed.heroHeight(accessibility: false) - 376.04) < 0.001)
    }

    @Test func aNewWidthStartsAFreshLatch() {
        let folded = sizing(container(402, 900, topInset: 120), container(300, 500, topInset: 60))

        #expect(folded.containerWidth == 300)
        #expect(folded.containerHeight == 500)
        #expect(folded.heroHeight(accessibility: false) == 340)
    }

    @Test func aNarrowPaneCapsTheFigureSoTheTurntableFits() {
        let pane = sizing(container(240, 900))

        #expect(pane.heroHeight(accessibility: false) == 500)
    }

    @Test func invalidReadingsAreIgnored() {
        let kept = sizing(
            container(402, 800),
            container(CGFloat.infinity, 900),
            container(402, CGFloat.nan),
            container(402, 900, topInset: -40)
        )

        #expect(kept.containerWidth == 402)
        #expect(kept.containerHeight == 800)
    }
}

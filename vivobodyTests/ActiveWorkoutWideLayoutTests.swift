//
//  ActiveWorkoutWideLayoutTests.swift
//  vivobodyTests
//
//  Pins the active workout on a wide window: the presentation chosen at
//  expansion (a cover on a hinged device in every pose) and kept through
//  layout changes, and the page lanes that stay clear of the fold inside
//  SwipePager's inset pages.
//

import CoreGraphics
import Testing
@testable import vivobody

@MainActor
struct ActiveWorkoutWideLayoutTests {
    private let windowWidth: CGFloat = 867
    private let fold = CGRect(x: 455, y: -82, width: 40, height: 669)
    private let pageInset: CGFloat = 18

    @Test func aHingeOrAWindowThatSplitsDashboardsGetsTheCover() {
        #expect(ActiveWorkoutPresentation(layout: .compact, hasHinge: false) == .sheet)
        #expect(ActiveWorkoutPresentation(layout: .regular, hasHinge: false) == .sheet)
        #expect(ActiveWorkoutPresentation(layout: .regularWide, hasHinge: false) == .cover)
        #expect(ActiveWorkoutPresentation(layout: .compact, hasHinge: true) == .cover)
        #expect(ActiveWorkoutPresentation(layout: .regular, hasHinge: true) == .cover)
    }

    @Test func theSheetKeepsOneColumnAndTheCoverFollowsTheWindow() {
        #expect(ActiveWorkoutPresentation.sheet.contentLayout(for: .regularWide) == .regular)
        #expect(ActiveWorkoutPresentation.sheet.contentLayout(for: .compact) == .compact)
        #expect(ActiveWorkoutPresentation.cover.contentLayout(for: .regularWide) == .regularWide)
        #expect(ActiveWorkoutPresentation.cover.contentLayout(for: .compact) == .compact)
    }

    @Test func aFoldedHingedDeviceKeepsTheCoverThroughAnUnfold() {
        var latch = ActiveWorkoutPresentationLatch()
        latch.update(isExpanded: true, layout: .compact, hasHinge: true)
        #expect(latch.presentation(for: .compact, hasHinge: true) == .cover)

        latch.update(isExpanded: true, layout: .regularWide, hasHinge: true)
        #expect(latch.presentation(for: .regularWide, hasHinge: true) == .cover)

        latch.update(isExpanded: true, layout: .compact, hasHinge: true)
        #expect(latch.presentation(for: .compact, hasHinge: true) == .cover)
    }

    @Test func aLayoutChangeDuringOneExpansionKeepsThePresentation() {
        var latch = ActiveWorkoutPresentationLatch()
        latch.update(isExpanded: true, layout: .regularWide, hasHinge: false)

        latch.update(isExpanded: true, layout: .compact, hasHinge: false)
        #expect(latch.presentation(for: .compact, hasHinge: false) == .cover)

        latch.update(isExpanded: false, layout: .compact, hasHinge: false)
        #expect(latch.presentation(for: .compact, hasHinge: false) == .sheet)

        latch.update(isExpanded: true, layout: .compact, hasHinge: false)
        latch.update(isExpanded: true, layout: .regularWide, hasHinge: false)
        #expect(latch.presentation(for: .regularWide, hasHinge: false) == .sheet)
    }

    @Test func beforeTheLatchTheLayoutAndHingeDecide() {
        let latch = ActiveWorkoutPresentationLatch()
        #expect(latch.presentation(for: .regularWide, hasHinge: false) == .cover)
        #expect(latch.presentation(for: .compact, hasHinge: false) == .sheet)
        #expect(latch.presentation(for: .compact, hasHinge: true) == .cover)
    }

    @Test func pageLanesKeepAGutterFromTheFold() {
        let lanes = ActiveWorkoutLanes(
            viewportWidth: windowWidth,
            divisions: [fold],
            pageInset: pageInset
        )

        #expect(lanes.page.leading == 20 ... 417)
        #expect(lanes.page.trailing == 497 ... 811)
        #expect(lanes.page.leading.upperBound + pageInset == fold.minX - 20)
        #expect(lanes.viewportTrailing == 515 ... 829)
        #expect(lanes.viewportTrailing.lowerBound == fold.maxX + 20)
    }

    @Test func theTrailingLaneEndsInsideThePage() {
        let pageWidth = windowWidth - 2 * pageInset
        for divisions in [[fold], []] {
            let lanes = ActiveWorkoutLanes(
                viewportWidth: windowWidth,
                divisions: divisions,
                pageInset: pageInset
            )
            #expect(lanes.page.trailing.upperBound == pageWidth - 20)
            #expect(lanes.viewportTrailing.upperBound == windowWidth - pageInset - 20)
        }
    }

    @Test func withoutAFoldThePageSplitsEvenly() {
        let lanes = ActiveWorkoutLanes(
            viewportWidth: windowWidth,
            divisions: [],
            pageInset: pageInset
        )

        #expect(lanes.page.leading == 20 ... 399.5)
        #expect(lanes.page.trailing == 431.5 ... 811)
        #expect(lanes.page.width(of: .leading) == lanes.page.width(of: .trailing))
    }
}

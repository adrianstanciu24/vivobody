//
//  BrowserColumnWidthsTests.swift
//  vivobodyTests
//
//  Pins where a browser's list ends: half the split view in a window that
//  splits dashboards, earlier at a fold left of the middle, never past the
//  middle, and near the system's width everywhere else.
//

import CoreGraphics
import Testing
@testable import vivobody

@MainActor
struct BrowserColumnWidthsTests {
    private func widths(
        width: CGFloat,
        folds: [CGRect] = [],
        splitsAtFold: Bool = true
    ) -> BrowserColumnWidths {
        BrowserColumnWidths(BrowserColumnGeometry(width: width, folds: folds), splitsAtFold: splitsAtFold)
    }

    @Test func wideWindowWithoutFoldSplitsInHalves() {
        let columns = widths(width: 867)
        #expect(columns.isPinned)
        #expect(columns.list == 433.5)
        #expect(columns.detail == 433.5)
    }

    @Test func foldLeftOfTheMiddleEndsTheList() {
        let columns = widths(width: 900, folds: [CGRect(x: 380, y: 0, width: 40, height: 600)])
        #expect(columns.list == 400)
        #expect(columns.detail == 500)
    }

    @Test func foldRightOfTheMiddleKeepsTheListAtHalf() {
        let columns = widths(width: 867, folds: [CGRect(x: 455.5, y: 0, width: 40, height: 669)])
        #expect(columns.list == 433.5)
        #expect(columns.detail == 433.5)
    }

    @Test func horizontalFoldDoesNotMoveTheList() {
        let columns = widths(width: 800, folds: [CGRect(x: 0, y: 300, width: 800, height: 40)])
        #expect(columns.list == 400)
    }

    @Test func otherWindowsKeepTheStandardList() {
        let columns = widths(width: 662, splitsAtFold: false)
        #expect(!columns.isPinned)
        #expect(columns.list == BrowserColumnWidths.standardList)
        #expect(columns.detail == 662 - BrowserColumnWidths.standardList)
    }

    @Test func unmeasuredWindowIsNotPinned() {
        let columns = widths(width: 0)
        #expect(!columns.isPinned)
        #expect(columns.detail == 0)
    }
}

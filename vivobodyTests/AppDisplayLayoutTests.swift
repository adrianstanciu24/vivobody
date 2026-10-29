//
//  AppDisplayLayoutTests.swift
//  vivobodyTests
//
//  Pins the shell's pane rule for every window shape: compact width keeps
//  one column, regular width adds list detail, and only a wide regular
//  window with fold-aware layout splits the dashboards.
//

import CoreGraphics
import SwiftUI
import Testing
@testable import vivobody

@MainActor
struct AppDisplayLayoutTests {
    private let wide = CGSize(width: 662, height: 466)
    private let tall = CGSize(width: 466, height: 662)
    private let square = CGSize(width: 500, height: 500)

    @Test func compactWidthShowsOneColumnForEveryShape() {
        for size in [wide, tall, square, .zero] {
            for supportsFoldLayout in [true, false] {
                let layout = AppDisplayLayout(
                    horizontalSizeClass: .compact,
                    windowSize: size,
                    supportsFoldLayout: supportsFoldLayout
                )
                #expect(layout == .compact)
            }
        }
    }

    @Test func unknownSizeClassKeepsThePhoneLayout() {
        let layout = AppDisplayLayout(
            horizontalSizeClass: nil,
            windowSize: wide,
            supportsFoldLayout: true
        )
        #expect(layout == .compact)
    }

    @Test func wideRegularWindowWithFoldLayoutSplitsDashboards() {
        let layout = AppDisplayLayout(
            horizontalSizeClass: .regular,
            windowSize: wide,
            supportsFoldLayout: true
        )
        #expect(layout == .regularWide)
    }

    @Test func tallOrSquareRegularWindowKeepsDashboardsInOneColumn() {
        for size in [tall, square] {
            let layout = AppDisplayLayout(
                horizontalSizeClass: .regular,
                windowSize: size,
                supportsFoldLayout: true
            )
            #expect(layout == .regular)
        }
    }

    @Test func wideRegularWindowWithoutFoldLayoutKeepsDashboardsInOneColumn() {
        let layout = AppDisplayLayout(
            horizontalSizeClass: .regular,
            windowSize: wide,
            supportsFoldLayout: false
        )
        #expect(layout == .regular)
    }

    @Test func eachLayoutExposesItsPanes() {
        #expect(AppDisplayLayout.compact.showsBrowserDetail == false)
        #expect(AppDisplayLayout.compact.showsDashboardColumns == false)
        #expect(AppDisplayLayout.regular.showsBrowserDetail == true)
        #expect(AppDisplayLayout.regular.showsDashboardColumns == false)
        #expect(AppDisplayLayout.regularWide.showsBrowserDetail == true)
        #expect(AppDisplayLayout.regularWide.showsDashboardColumns == true)
    }

    @Test func environmentDefaultsToThePhoneLayout() {
        #expect(EnvironmentValues().appDisplayLayout == .compact)
    }
}

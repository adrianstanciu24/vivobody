//
//  ExerciseFrequencyTests.swift
//  vivobodyTests
//
//  Guards the typical-weekly-frequency rate behind the Exercise Detail
//  hero-card footer's "Per week" cell. Pure date math on a virtual
//  clock — no simulator.
//
//  Covered:
//    • Gating — fewer than two sessions or a sub-week span → nil.
//    • Young history — rates divide by elapsed weeks, not the full
//      eight-week window.
//    • Long history — only the trailing eight weeks count.
//    • Future-dated sessions never count.
//

import Foundation
import Testing
@testable import vivobody

struct ExerciseFrequencyTests {
    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date {
        Self.origin.addingTimeInterval(n * 86400)
    }

    @Test func fewerThanTwoSessionsIsNil() {
        #expect(ExerciseFrequency.perWeek(sessionDates: [], now: day(0)) == nil)
        #expect(ExerciseFrequency.perWeek(sessionDates: [day(-10)], now: day(0)) == nil)
    }

    @Test func subWeekSpanIsNil() {
        let dates = [day(-1), day(-3)]
        #expect(ExerciseFrequency.perWeek(sessionDates: dates, now: day(0)) == nil)
    }

    @Test func exactWeekSpanQualifies() {
        // 2 sessions over exactly 7 days → 2 per week.
        let dates = [day(0), day(-7)]
        let rate = ExerciseFrequency.perWeek(sessionDates: dates, now: day(0))
        #expect(abs((rate ?? 0) - 2) < 0.0001)
    }

    @Test func youngHistoryDividesByElapsedWeeks() {
        // 4 sessions, oldest 17 days ago → 4 / (17/7) ≈ 1.65.
        let dates = [day(-2), day(-4), day(-10), day(-17)]
        let rate = ExerciseFrequency.perWeek(sessionDates: dates, now: day(0))
        #expect(abs((rate ?? 0) - 4.0 / (17.0 / 7.0)) < 0.0001)
    }

    @Test func longHistoryUsesOnlyTheTrailingWindow() {
        // Oldest session 100 days ago: only the four sessions inside
        // the trailing 8 weeks count → 4 / 8 = 0.5 per week.
        let dates = [day(-10), day(-20), day(-30), day(-40), day(-70), day(-100)]
        let rate = ExerciseFrequency.perWeek(sessionDates: dates, now: day(0))
        #expect(abs((rate ?? 0) - 0.5) < 0.0001)
    }

    @Test func windowBoundarySessionCounts() {
        // A session exactly 56 days back sits inside the window.
        let dates = [day(-56), day(-57)]
        let rate = ExerciseFrequency.perWeek(sessionDates: dates, now: day(0))
        #expect(abs((rate ?? 0) - 1.0 / 8.0) < 0.0001)
    }

    @Test func futureDatesAreIgnored() {
        // Only one past session remains after filtering → nil.
        let dates = [day(-10), day(3)]
        #expect(ExerciseFrequency.perWeek(sessionDates: dates, now: day(0)) == nil)
    }
}

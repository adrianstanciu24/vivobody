//
//  ProgressionCadenceTests.swift
//  vivobodyTests
//
//  Guards the per-exercise load-progression rhythm on a virtual
//  clock: running-max step-up detection (deload returns are not
//  increases), the minimum-increase gate, median gap robustness,
//  same-day clamping, and the comparable-load eligibility filter.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ProgressionCadenceTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func point(
        daysAgo: Int,
        load: Double,
        hoursOffset: Int = 0,
        loadMode: ExerciseLoadMode = .external
    ) -> ExerciseProgressPoint {
        var date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        date = calendar.date(byAdding: .hour, value: hoursOffset, to: date)!
        return ExerciseProgressPoint(
            date: date,
            topWeight: load,
            topReps: 8,
            loadMode: loadMode,
            totalVolume: 0,
            comparableTonnageAvailability: .complete
        )
    }

    private func compute(_ points: [ExerciseProgressPoint]) -> ProgressionCadence? {
        ProgressionCadence.compute(points: points, now: now, calendar: calendar)
    }

    // MARK: - Rhythm detection

    @Test func steadyWeeklyIncreasesReadAsSevenDayRhythm() {
        let cadence = compute([
            point(daysAgo: 30, load: 100),
            point(daysAgo: 23, load: 105),
            point(daysAgo: 16, load: 110),
            point(daysAgo: 9, load: 115),
            point(daysAgo: 2, load: 120),
        ])
        #expect(cadence != nil)
        #expect(cadence?.medianGapDays == 7)
        #expect(cadence?.increases.count == 4)
        #expect(cadence?.events.count == 5)
        #expect(cadence?.baseline.load == 100)
        #expect(cadence?.daysSinceLastIncrease == 2)
        #expect(cadence?.isPastUsualRhythm == false)
    }

    @Test func deloadReturnIsNotAnIncrease() {
        let cadence = compute([
            point(daysAgo: 30, load: 100),
            point(daysAgo: 23, load: 110),  // increase
            point(daysAgo: 16, load: 90),   // deload
            point(daysAgo: 9, load: 110),   // return to prior max — not an increase
            point(daysAgo: 2, load: 115),   // increase
        ])
        #expect(cadence?.increases.count == 2)
        #expect(cadence?.increases.map(\.load) == [110, 115])
        // Gaps: baseline→7d, then 21d. Even count averages to 14.
        #expect(cadence?.medianGapDays == 14)
    }

    @Test func medianResistsOneLongOutlierGap() {
        let cadence = compute([
            point(daysAgo: 44, load: 100),
            point(daysAgo: 37, load: 105),
            point(daysAgo: 30, load: 110),
            point(daysAgo: 2, load: 115),   // 28-day vacation gap
        ])
        #expect(cadence?.medianGapDays == 7)
    }

    @Test func sameDayIncreasesClampToOneDayGap() {
        let cadence = compute([
            point(daysAgo: 10, load: 100),
            point(daysAgo: 10, load: 105, hoursOffset: 2),  // same calendar day
            point(daysAgo: 3, load: 110),
        ])
        // Gaps clamp to [1, 7]; even count averages to 4.
        #expect(cadence?.medianGapDays == 4)
    }

    @Test func pastUsualRhythmFlagsWhenGapOutrunsMedian() {
        let cadence = compute([
            point(daysAgo: 31, load: 100),
            point(daysAgo: 24, load: 105),
            point(daysAgo: 17, load: 110),
            point(daysAgo: 10, load: 115),
        ])
        #expect(cadence?.medianGapDays == 7)
        #expect(cadence?.daysSinceLastIncrease == 10)
        #expect(cadence?.isPastUsualRhythm == true)
    }

    // MARK: - Gates

    @Test func singleIncreaseIsNotARhythm() {
        let cadence = compute([
            point(daysAgo: 14, load: 100),
            point(daysAgo: 7, load: 105),
        ])
        #expect(cadence == nil)
    }

    @Test func flatHistoryHasNoCadence() {
        let cadence = compute([
            point(daysAgo: 21, load: 100),
            point(daysAgo: 14, load: 100),
            point(daysAgo: 7, load: 100),
        ])
        #expect(cadence == nil)
    }

    @Test func emptyHistoryIsNil() {
        #expect(compute([]) == nil)
    }

    @Test func nonComparableWorkIsExcluded() {
        let cadence = compute([
            point(daysAgo: 21, load: 100, loadMode: .nonComparable),
            point(daysAgo: 14, load: 110, loadMode: .nonComparable),
            point(daysAgo: 7, load: 120, loadMode: .nonComparable),
        ])
        #expect(cadence == nil)
    }

    @Test func unknownBodyweightPointsAreSkipped() {
        // bodyweightAtSession defaults to the unknown sentinel, so
        // bodyweight-added points have no recoverable effective load.
        let cadence = compute([
            point(daysAgo: 21, load: 10, loadMode: .bodyweightAdded),
            point(daysAgo: 14, load: 15, loadMode: .bodyweightAdded),
            point(daysAgo: 7, load: 20, loadMode: .bodyweightAdded),
        ])
        #expect(cadence == nil)
    }
}

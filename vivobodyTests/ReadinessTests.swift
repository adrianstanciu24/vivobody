//
//  ReadinessTests.swift
//  vivobodyTests
//
//  Guards the Today body figure's readiness line on a virtual clock:
//  the cold-start nil, the "trained today" short-circuit, the recency
//  voice before the load baseline forms, and the trend-verdict lines
//  once it has.
//

import Foundation
import Testing
@testable import vivobody

struct ReadinessTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A completed session of one lift, `daysAgo` before `now`, whose
    /// tonnage is `weight × reps × sets`.
    private func session(daysAgo: Double, weight: Double, reps: Int, sets: Int) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let ex = Exercise(name: "Bench Press", group: .chest, plannedSets: 0, plannedWeight: 0)
        for i in 0..<sets {
            ex.sets.append(WorkoutSet(weight: weight, reps: reps, isCompleted: true, sortOrder: i))
        }
        let s = WorkoutSession(exercises: [ex], startedAt: date)
        s.completedAt = date
        return s
    }

    /// Sits at 30 days ago so the four-week history gate opens; far
    /// enough back that it falls outside the 28-day chronic sum.
    private func historyAnchor(load: Double) -> WorkoutSession {
        session(daysAgo: 30, weight: load, reps: 1, sets: 1)
    }

    // MARK: - Cold start & "today"

    @Test func coldStartIsNil() {
        #expect([WorkoutSession]().readiness(now: now) == nil)
    }

    @Test func trainedTodayShortCircuits() {
        let line = [session(daysAgo: 0, weight: 100, reps: 10, sets: 3)].readiness(now: now)
        #expect(line?.lead == "Today's in the bank.")
    }

    // MARK: - Forming (recency voice, under three weeks of history)

    @Test func oneDayRest() {
        let sessions = [
            session(daysAgo: 1, weight: 100, reps: 10, sets: 3),
            session(daysAgo: 8, weight: 100, reps: 10, sets: 3),
        ]
        #expect(sessions.readiness(now: now)?.lead == "One day's rest.")
    }

    @Test func freshFewDaysRest() {
        let sessions = [
            session(daysAgo: 3, weight: 100, reps: 10, sets: 3),
            session(daysAgo: 8, weight: 100, reps: 10, sets: 3),
        ]
        #expect(sessions.readiness(now: now)?.lead == "Fresh — 3 days' rest.")
    }

    @Test func daysOffEaseBack() {
        let sessions = [
            session(daysAgo: 5, weight: 100, reps: 10, sets: 3),
            session(daysAgo: 8, weight: 100, reps: 10, sets: 3),
        ]
        #expect(sessions.readiness(now: now)?.lead == "5 days off.")
    }

    @Test func longLayoffWelcomeBack() {
        let line = [session(daysAgo: 9, weight: 100, reps: 10, sets: 3)].readiness(now: now)
        #expect(line?.lead == "It's been 9 days.")
    }

    // MARK: - Trend verdicts (with a four-week history anchor)

    @Test func optimalRestedReadsInTheZone() {
        // Steady 1000/wk, most recent session two days ago → optimal +
        // rested.
        var sessions = [2.0, 9, 16, 23].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 1) }
        sessions.append(historyAnchor(load: 1000))
        #expect(sessions.readiness(now: now)?.lead == "Fresh and in the zone.")
    }

    @Test func optimalRecentReadsBuildZone() {
        // Steady 1000/wk, most recent session only one day ago → optimal
        // but not "rested".
        var sessions = [1.0, 8, 15, 22].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 1) }
        sessions.append(historyAnchor(load: 1000))
        #expect(sessions.readiness(now: now)?.lead == "Right in the build zone.")
    }

    @Test func spikeReadsRunningHot() {
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 50, reps: 10, sets: 1) }
        sessions.append(session(daysAgo: 2, weight: 100, reps: 10, sets: 2))
        sessions.append(historyAnchor(load: 500))
        #expect(sessions.readiness(now: now)?.lead == "Running hot.")
    }

    @Test func elevatedReadsStrongWeek() {
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 1) }
        sessions.append(session(daysAgo: 2, weight: 100, reps: 16, sets: 1))
        sessions.append(historyAnchor(load: 1000))
        #expect(sessions.readiness(now: now)?.lead == "Strong week.")
    }

    @Test func droppedLoadReadsCoasting() {
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 2) }
        sessions.append(session(daysAgo: 2, weight: 50, reps: 5, sets: 1))
        sessions.append(historyAnchor(load: 2000))
        #expect(sessions.readiness(now: now)?.lead == "Coasting lately.")
    }

    // MARK: - Phrase assembly

    @Test func phraseJoinsLeadAndTail() {
        #expect(ReadinessLine(lead: "Running hot.", tail: "Back off today.").phrase
            == "Running hot. Back off today.")
        #expect(ReadinessLine(lead: "Fresh and in the zone.", tail: "").phrase
            == "Fresh and in the zone.")
    }
}

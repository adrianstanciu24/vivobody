//
//  ReadinessTests.swift
//  vivobodyTests
//
//  Guards the Today body figure's readiness line on a virtual clock:
//  the cold-start nil, the "trained today" short-circuit, the recency
//  voice before the load baseline forms, and the workload-status lines
//  once it has.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ReadinessTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A completed session of one lift, `daysAgo` before `now`.
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

    // MARK: - Workload status

    @Test func productiveRestedReadsFreshAndOnPlan() {
        let sessions = [2.0, 9, 16, 23, 30].map {
            session(daysAgo: $0, weight: 100, reps: 8, sets: 2)
        }
        #expect(sessions.readiness(now: now)?.lead == "Fresh and on plan.")
    }

    @Test func productiveRecentNamesTheLoad() {
        let sessions = [1.0, 8, 15, 22, 29].map {
            session(daysAgo: $0, weight: 100, reps: 8, sets: 2)
        }
        #expect(sessions.readiness(now: now)?.lead == "Productive training load.")
    }

    @Test func highLoadReadsHighWithoutRecoveryClaim() {
        var sessions = [9.0, 16, 23, 30].map {
            session(daysAgo: $0, weight: 100, reps: 8, sets: 2)
        }
        sessions.append(session(daysAgo: 2, weight: 100, reps: 8, sets: 4))
        #expect(sessions.readiness(now: now)?.lead == "Training load is high.")
    }

    @Test func lowLoadReadsLighterLately() {
        var sessions = [9.0, 16, 23, 30].map {
            session(daysAgo: $0, weight: 100, reps: 8, sets: 4)
        }
        sessions.append(session(daysAgo: 2, weight: 100, reps: 8, sets: 2))
        #expect(sessions.readiness(now: now)?.lead == "Load is lighter lately.")
    }

    // MARK: - Phrase assembly

    @Test func phraseJoinsLeadAndTail() {
        #expect(ReadinessLine(lead: "Training load is high.", tail: "Keep today lighter.").phrase
            == "Training load is high. Keep today lighter.")
        #expect(ReadinessLine(lead: "Fresh and on plan.", tail: "").phrase
            == "Fresh and on plan.")
    }
}

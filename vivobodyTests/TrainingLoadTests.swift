//
//  TrainingLoadTests.swift
//  vivobodyTests
//
//  Guards the acute:chronic workload ratio (ACWR) on a virtual clock:
//  the 7-day acute / 28-day chronic split, the four-week history gate,
//  and the verdict bands.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct TrainingLoadTests {

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

    // MARK: - History gate

    @Test func insufficientUnderThreeWeeks() {
        let sessions = [
            session(daysAgo: 1, weight: 100, reps: 10, sets: 3),
            session(daysAgo: 8, weight: 100, reps: 10, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now)
        #expect(report.verdict == .insufficient)
        #expect(report.hasEnoughHistory == false)
    }

    @Test func emptyHistoryIsInsufficient() {
        let report = [WorkoutSession]().trainingLoad(now: now)
        #expect(report.verdict == .insufficient)
        #expect(report.acuteLoad == 0)
    }

    // MARK: - Ratio math (with a four-week history anchor)

    @Test func steadyLoadReadsOptimal() {
        // 1000 lb each of the last four weeks → acute 1000, chronic
        // 4000/4 = 1000, ratio 1.0.
        var sessions = [2.0, 9, 16, 23].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 1) }
        sessions.append(historyAnchor(load: 1000)) // opens the gate, outside the 28d sum
        let report = sessions.trainingLoad(now: now)
        #expect(abs(report.acuteLoad - 1000) < 0.001)
        #expect(abs(report.chronicWeekly - 1000) < 0.001)
        #expect(abs(report.ratio - 1.0) < 0.001)
        #expect(report.verdict == .optimal)
    }

    @Test func spikeReadsOverreaching() {
        // Quiet baseline weeks (500) then a heavy acute week (2000).
        // Chronic = (500×3 + 2000)/4 = 875; ratio = 2000/875 ≈ 2.29.
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 50, reps: 10, sets: 1) }
        sessions.append(session(daysAgo: 2, weight: 100, reps: 10, sets: 2)) // 2000
        sessions.append(historyAnchor(load: 500))
        let report = sessions.trainingLoad(now: now)
        #expect(report.ratio > 1.5)
        #expect(report.verdict == .overreaching)
    }

    @Test func droppedLoadReadsDetraining() {
        // Heavy baseline weeks (2000) then a near-empty acute week.
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 2) } // 2000 each
        sessions.append(session(daysAgo: 2, weight: 50, reps: 5, sets: 1)) // 250
        sessions.append(historyAnchor(load: 2000))
        let report = sessions.trainingLoad(now: now)
        #expect(report.ratio < 0.8)
        #expect(report.verdict == .detraining)
    }

    @Test func slightlyElevatedReadsPushing() {
        // Baseline 1000/wk, acute 1600. Chronic = (1000×3 + 1600)/4 =
        // 1150; ratio = 1600/1150 ≈ 1.39 → pushing (1.3–1.5 band).
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 100, reps: 10, sets: 1) } // 1000 each
        sessions.append(session(daysAgo: 2, weight: 100, reps: 16, sets: 1)) // 1600 acute
        sessions.append(historyAnchor(load: 1000))
        let report = sessions.trainingLoad(now: now)
        #expect(report.ratio > 1.3 && report.ratio < 1.5)
        #expect(report.verdict == .pushing)
    }

    // MARK: - Weekly series

    @Test func weeklySeriesIsChronologicalZeroFilledAndFlagsCurrent() {
        // A session today and one 16 days back leave at least one
        // empty week between them inside the clipped range, under
        // both Sunday-first and Monday-first week conventions.
        let sessions = [
            session(daysAgo: 0, weight: 100, reps: 10, sets: 1),   // 1000, current week
            session(daysAgo: 16, weight: 100, reps: 10, sets: 2),  // 2000
        ]
        let report = sessions.trainingLoad(now: now)
        let weeks = report.weeks

        #expect(!weeks.isEmpty)
        #expect(weeks == weeks.sorted { $0.weekStart < $1.weekStart })
        // Clipped to the first session's week — no leading empty tail.
        #expect(weeks.count <= 4)
        // Exactly the last column is the current week.
        #expect(weeks.last?.isCurrent == true)
        #expect(weeks.dropLast().allSatisfy { !$0.isCurrent })
        // Tonnage lands in the right buckets and sums to the total.
        #expect(abs(weeks.last!.load - 1000) < 0.001)
        #expect(abs(weeks.reduce(0) { $0 + $1.load } - 3000) < 0.001)
        // At least one zero-filled gap week exists between the two.
        #expect(weeks.contains { $0.load == 0 })
    }

    @Test func weeklySeriesCapsAtTwelveWeeks() {
        // Two years of weekly sessions — the series must clip to 12.
        let sessions = stride(from: 0.0, through: 700, by: 7).map {
            session(daysAgo: $0, weight: 100, reps: 10, sets: 1)
        }
        let report = sessions.trainingLoad(now: now)
        #expect(report.weeks.count == 12)
        #expect(report.weeks.allSatisfy { $0.load > 0 })
    }

    @Test func emptyHistoryHasNoWeeks() {
        #expect([WorkoutSession]().trainingLoad(now: now).weeks.isEmpty)
    }
}

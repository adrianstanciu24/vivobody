//
//  UpNextTests.swift
//  vivobodyTests
//
//  Guards the schedule-driven "Up next" engine on a virtual clock:
//  the unscheduled short-circuit, train-today, the rest-day rollover
//  (off-day vs already-trained), week wrap-around, same-day rotation,
//  and the overreaching ease-off flag.
//

import Foundation
import Testing
@testable import vivobody

struct UpNextTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let cal = Calendar.current

    /// The `Calendar` weekday number `offset` days from today.
    private func weekday(offset: Int) -> Int {
        let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
        return cal.component(.weekday, from: day)
    }

    private func template(
        name: String,
        days: [Int],
        lastUsed: Date? = nil,
        sortOrder: Int = 0
    ) -> WorkoutTemplate {
        let t = WorkoutTemplate(
            name: name,
            exercises: [TemplateExercise(name: "Bench Press", group: .chest, plannedWeight: 135, sortOrder: 0)],
            sortOrder: sortOrder
        )
        t.scheduledWeekdays = days
        t.lastUsedAt = lastUsed
        return t
    }

    private func session(daysAgo: Double, weight: Double = 100, reps: Int = 10, sets: Int = 3) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let ex = Exercise(name: "Bench Press", group: .chest, plannedSets: 0, plannedWeight: 0)
        for i in 0..<sets {
            ex.sets.append(WorkoutSet(weight: weight, reps: reps, isCompleted: true, sortOrder: i))
        }
        let s = WorkoutSession(exercises: [ex], startedAt: date)
        s.completedAt = date
        return s
    }

    // MARK: - Unscheduled

    @Test func unscheduledWhenNoDaysSet() {
        let upNext = UpNext.compute(templates: [template(name: "Push", days: [])], sessions: [], now: now, calendar: cal)
        guard case .unscheduled = upNext.kind else { Issue.record("expected unscheduled"); return }
        #expect(upNext.isPresentable == false)
    }

    // MARK: - Train today

    @Test func scheduledTodayIsStartable() {
        let t = template(name: "Push", days: [weekday(offset: 0)])
        let upNext = UpNext.compute(templates: [t], sessions: [], now: now, calendar: cal)
        guard case let .scheduled(template, more, easeOff) = upNext.kind else { Issue.record("expected scheduled"); return }
        #expect(template.name == "Push")
        #expect(more == 0)
        #expect(easeOff == false)
        #expect(upNext.isPresentable)
    }

    @Test func multiplePerDayPicksLeastRecentlyUsed() {
        let recent = template(name: "RecentPush", days: [weekday(offset: 0)], lastUsed: now.addingTimeInterval(-86_400), sortOrder: 0)
        let stale = template(name: "StalePush", days: [weekday(offset: 0)], lastUsed: now.addingTimeInterval(-10 * 86_400), sortOrder: 1)
        let upNext = UpNext.compute(templates: [recent, stale], sessions: [], now: now, calendar: cal)
        guard case let .scheduled(template, more, _) = upNext.kind else { Issue.record("expected scheduled"); return }
        #expect(template.name == "StalePush")
        #expect(more == 1)
    }

    @Test func easeOffWhenOverreaching() {
        let t = template(name: "Push", days: [weekday(offset: 0)])
        var sessions = [9.0, 16, 23].map { session(daysAgo: $0, weight: 50, reps: 10, sets: 1) }
        sessions.append(session(daysAgo: 2, weight: 100, reps: 10, sets: 2)) // acute spike
        sessions.append(session(daysAgo: 30, weight: 500, reps: 1, sets: 1)) // opens history gate
        let upNext = UpNext.compute(templates: [t], sessions: sessions, now: now, calendar: cal)
        guard case let .scheduled(_, _, easeOff) = upNext.kind else { Issue.record("expected scheduled"); return }
        #expect(easeOff)
    }

    // MARK: - Rest days

    @Test func tomorrowReadsRestOffDay() {
        let t = template(name: "Legs", days: [weekday(offset: 1)])
        let upNext = UpNext.compute(templates: [t], sessions: [], now: now, calendar: cal)
        guard case let .rest(reason, next, daysUntil, _) = upNext.kind else { Issue.record("expected rest"); return }
        #expect(reason == .offDay)
        #expect(next?.name == "Legs")
        #expect(daysUntil == 1)
    }

    @Test func offDayInThreeDays() {
        let t = template(name: "Legs", days: [weekday(offset: 3)])
        let upNext = UpNext.compute(templates: [t], sessions: [], now: now, calendar: cal)
        guard case let .rest(reason, _, daysUntil, _) = upNext.kind else { Issue.record("expected rest"); return }
        #expect(reason == .offDay)
        #expect(daysUntil == 3)
    }

    @Test func trainedTodayAdvancesToNext() {
        let today = template(name: "Push", days: [weekday(offset: 0)], sortOrder: 0)
        let later = template(name: "Pull", days: [weekday(offset: 3)], sortOrder: 1)
        let upNext = UpNext.compute(templates: [today, later], sessions: [session(daysAgo: 0)], now: now, calendar: cal)
        guard case let .rest(reason, next, daysUntil, _) = upNext.kind else { Issue.record("expected rest"); return }
        #expect(reason == .doneToday)
        #expect(next?.name == "Pull")
        #expect(daysUntil == 3)
    }

    @Test func onlyTodayScheduledAndTrainedRollsAWeek() {
        let t = template(name: "Push", days: [weekday(offset: 0)])
        let upNext = UpNext.compute(templates: [t], sessions: [session(daysAgo: 0)], now: now, calendar: cal)
        guard case let .rest(reason, next, daysUntil, _) = upNext.kind else { Issue.record("expected rest"); return }
        #expect(reason == .doneToday)
        #expect(next?.name == "Push")
        #expect(daysUntil == 7)
    }
}

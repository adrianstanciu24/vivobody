//
//  ExerciseFrequency.swift
//  vivobody
//
//  Typical weekly frequency for one exercise — the "Per week" cell of
//  the Exercise Detail hero-card footer. Pure and clock-injected.
//  Descriptive only: the value never feeds verdicts, readiness, or
//  coaching copy.
//

import Foundation

nonisolated enum ExerciseFrequency {
    /// Long histories are rated over the trailing eight weeks.
    static let windowDays: Double = 56

    /// A rate needs at least a week of span to mean anything.
    static let minimumSpanDays: Double = 7

    /// Sessions per week over the trailing window. Young exercises
    /// (first session under eight weeks ago) divide by their elapsed
    /// weeks instead, so they are not diluted by weeks that predate
    /// them. Nil with fewer than two sessions or a sub-week span.
    static func perWeek(
        sessionDates: [Date],
        now: Date = Date()
    ) -> Double? {
        let dates = sessionDates.filter { $0 <= now }
        guard dates.count >= 2, let first = dates.min() else { return nil }

        let spanDays = now.timeIntervalSince(first) / 86400
        guard spanDays >= minimumSpanDays else { return nil }

        let window = min(windowDays, spanDays)
        let cutoff = now.addingTimeInterval(-window * 86400)
        let count = dates.count(where: { $0 >= cutoff })
        return Double(count) / (window / 7)
    }
}

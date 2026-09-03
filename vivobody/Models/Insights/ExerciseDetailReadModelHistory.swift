//
//  ExerciseDetailReadModelHistory.swift
//  vivobody
//
//  Pure history-facing derivations for ExerciseDetailReadModel: exact
//  frequency, bounded recent rows, record badges, and their complete
//  display and accessibility text.
//

import Foundation

extension ExerciseDetailReadModel {
    @MainActor
    static func frequency(
        history: ExerciseHistorySummary?,
        progress: ExerciseProgress?,
        now: Date,
        calendar: Calendar
    ) -> Frequency? {
        guard let history, history.sessionCount > 0 else { return nil }
        let count = history.sessionCount
        let rate = progress.flatMap {
            ExerciseFrequency.perWeek(
                sessionDates: $0.points.map(\.date),
                now: now
            )
        }
        let rateText = rate.map(perWeekLabel)
        let lastText = RelativeDate.short(
            history.mostRecentInstance.date,
            now: now,
            calendar: calendar
        )
        let sessionsAccessibility = "\(count) \(count == 1 ? "session" : "sessions")"
        let rateAccessibility = rateText.map { "\($0) per week" }
            ?? "Weekly frequency not yet available"
        let lastAccessibility = "Last \(lastText)"
        return Frequency(
            sessionCount: count,
            sessionCountText: "\(count)",
            sessionsAccessibilityLabel: sessionsAccessibility,
            perWeek: rate,
            perWeekText: rateText.map { "\($0)×" } ?? "—",
            perWeekAccessibilityLabel: rateAccessibility,
            lastDate: history.mostRecentInstance.date,
            lastDateText: lastText,
            lastDateAccessibilityLabel: lastAccessibility,
            accessibilityLabel: "\(sessionsAccessibility), \(rateAccessibility), \(lastAccessibility.lowercased())"
        )
    }

    @MainActor
    static func recentSessions(
        history: ExerciseHistorySummary?,
        supportsPerformanceRecord: Bool,
        unit: WeightUnit,
        now: Date,
        calendar: Calendar
    ) -> [RecentSession] {
        guard let history else { return [] }
        let instances = history.recentInstances.isEmpty
            ? [history.mostRecentInstance]
            : history.recentInstances
        return instances.prefix(recentSessionLimit).map { instance in
            let source = RecordSource(instance)
            let metric = metricText(source: source, unit: unit)
            let relative = RelativeDate.short(
                source.date,
                now: now,
                calendar: calendar
            )
            let dateText = source.date.formatted(
                .dateTime.month(.abbreviated).day()
            )
            let count = instance.completedSetPrescription.count
            let setText = "\(count) \(count == 1 ? "set" : "sets")"
            let isRecord = supportsPerformanceRecord
                && instance.representativePerformance != nil
                && instance.representativePerformance == history.currentAllTimeBest
            let recordText = isRecord ? ", personal record" : ""
            return RecentSession(
                date: source.date,
                dateText: dateText,
                relativeDateText: relative,
                metric: metric,
                completedSetCount: count,
                setCountText: "× \(count)",
                isPersonalRecord: isRecord,
                accessibilityLabel: "\(dateText), \(relative), \(metric.accessibilityLabel), \(setText)\(recordText)"
            )
        }
    }

    static func perWeekLabel(_ value: Double) -> String {
        let oneDecimal = (value * 10).rounded() / 10
        return oneDecimal == oneDecimal.rounded()
            ? String(format: "%.0f", oneDecimal)
            : String(format: "%.1f", oneDecimal)
    }
}

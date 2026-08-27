//
//  RelativeDate.swift
//  vivobody
//
//  Compact, testable relative dates for exercise-history decorations.
//

import Foundation

enum RelativeDate {
    static func short(
        _ date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days < 0 { return "today" }
        if days < 14 { return "\(days)d ago" }

        let weeks = days / 7
        if weeks < 8 { return "\(weeks)w ago" }

        let months = days / 30
        if months < 6 { return "\(months)mo ago" }
        return "6+ mo ago"
    }
}

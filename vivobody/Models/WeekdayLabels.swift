//
//  WeekdayLabels.swift
//  vivobody
//
//  Locale-aware weekday helpers shared by the template schedule editor
//  (the S M T W T F S chip row) and the Library card / Up-next summary.
//  Weekday numbers follow `Calendar`'s convention (1 = Sunday … 7 =
//  Saturday); display order honours the user's `firstWeekday`.
//

import Foundation

enum WeekdayLabels {
    /// Weekday numbers in display order, starting at the calendar's
    /// first weekday (e.g. [2,3,4,5,6,7,1] for a Monday-first locale).
    static func ordered(_ calendar: Calendar = .current) -> [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    /// Single-letter symbol for a chip ("S", "M", …).
    static func veryShort(_ weekday: Int, _ calendar: Calendar = .current) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }

    /// Abbreviated symbol for inline text ("Mon", "Thu", …).
    static func short(_ weekday: Int, _ calendar: Calendar = .current) -> String {
        let symbols = calendar.shortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }

    /// Compact summary of a set of weekdays in week order, e.g.
    /// "Mon · Thu". Empty when no days are given.
    static func summary(_ weekdays: [Int], _ calendar: Calendar = .current) -> String {
        let set = Set(weekdays)
        return ordered(calendar)
            .filter(set.contains)
            .map { short($0, calendar) }
            .joined(separator: " · ")
    }
}

//
//  DurationFormatter.swift
//  vivobody
//
//  Central formatting + scrubber metadata for timed (`.duration`)
//  exercises — the isometric / hold counterpart to WeightFormatter.
//  A timed set is stored as a `TimeInterval` of seconds on WorkoutSet
//  / TemplateSet; every display site routes through here so the
//  minutes:seconds presentation stays consistent across the app
//  (the live hero, set rows, summary, history, progress, editors).
//

import Foundation

nonisolated enum DurationFormatter {

    // MARK: - String formatting

    /// Minutes:seconds with a two-digit seconds field — "0:45",
    /// "1:30", "12:00". The canonical form for big hero numerals and
    /// audit-style rows where alignment matters.
    static func string(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Compact form for tight inline captions: under a minute reads
    /// as "45s"; a minute or more falls back to "m:ss". Used where
    /// the value sits next to other text and the leading "0:" would
    /// be noise.
    static func compact(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total)s" }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Signed change between two holds for trend chips — "+0:15",
    /// "-0:05". The `.duration` counterpart to
    /// `WeightFormatter.deltaString`.
    static func deltaString(_ seconds: TimeInterval) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        return "\(sign)\(string(abs(seconds)))"
    }

    // MARK: - Scrubber metadata

    /// Range for the duration scrubber, in seconds. 5s covers the
    /// briefest hold; 600s (10 min) covers long timed carries and
    /// extended planks. Lower bound is 5 (a 0-second hold is
    /// meaningless — weight, not time, is what's optional here).
    static let scrubRange: ClosedRange<Double> = 5...600

    /// Scrubber step, in seconds. 5s is the natural increment for
    /// holds — fine enough to dial in a plank, coarse enough that a
    /// short drag spans a useful range.
    static let scrubStep: Double = 5
}

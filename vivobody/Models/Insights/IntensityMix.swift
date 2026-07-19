//
//  IntensityMix.swift
//  vivobody
//
//  How your working sets split across rep ranges — the "what kind of
//  training is this, really?" lens. Strength counts e1RM; volume
//  landmarks count sets; this asks at what INTENSITY those sets were
//  done:
//    • strength    — 1–5 reps (heavy, neural)
//    • hypertrophy — 6–12 reps (the growth zone)
//    • endurance   — 13+ reps (metabolic / conditioning)
//
//  Counts completed dynamic-strength `.reps` sets over a rolling
//  window (4 weeks by default, to read CURRENT emphasis). Timed holds,
//  conditioning reps, and mobility drills are excluded. Pure value-
//  type computation on injected dates (see `IntensityMixTests`).
//

import Foundation

// MARK: - Zone

nonisolated enum IntensityZone: Hashable, CaseIterable {
    case strength
    case hypertrophy
    case endurance

    /// Bucket a completed set's rep count. Reps ≤ 0 should be filtered
    /// by the caller (an unlogged set), but guard anyway.
    static func zone(forReps reps: Int) -> IntensityZone {
        switch reps {
        case ...5:   return .strength
        case 6...12: return .hypertrophy
        default:     return .endurance
        }
    }

    var label: String {
        switch self {
        case .strength:    return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance:   return "Endurance"
        }
    }

    var repRange: String {
        switch self {
        case .strength:    return "1–5"
        case .hypertrophy: return "6–12"
        case .endurance:   return "13+"
        }
    }
}

// MARK: - Mix

nonisolated struct IntensityMix: Hashable {
    let strengthSets: Int
    let hypertrophySets: Int
    let enduranceSets: Int

    var total: Int { strengthSets + hypertrophySets + enduranceSets }
    var hasData: Bool { total > 0 }

    func count(_ zone: IntensityZone) -> Int {
        switch zone {
        case .strength:    return strengthSets
        case .hypertrophy: return hypertrophySets
        case .endurance:   return enduranceSets
        }
    }

    /// Fraction (0…1) of working sets in a zone.
    func share(_ zone: IntensityZone) -> Double {
        total > 0 ? Double(count(zone)) / Double(total) : 0
    }

    /// The zone carrying the most sets, or nil when there's no data.
    /// Ties resolve toward the heavier end (strength → hypertrophy →
    /// endurance) so a tie never reads as "high-rep heavy".
    var dominant: IntensityZone? {
        guard hasData else { return nil }
        return IntensityZone.allCases.max { count($0) < count($1) }
    }
}

// MARK: - Weekly breakdown

/// One calendar week's zone counts — the bars of the Insights
/// intensity chart. Weeks with no completed `.reps` sets are omitted
/// by the aggregator, so a gap in training reads as a gap. The current
/// calendar week is marked so the chart can present it as incomplete
/// rather than implying a finished-week drop.
nonisolated struct IntensityWeek: Identifiable, Hashable {
    var id: Date { weekStart }
    let weekStart: Date
    let strengthSets: Int
    let hypertrophySets: Int
    let enduranceSets: Int
    let isCurrentWeek: Bool

    var total: Int { strengthSets + hypertrophySets + enduranceSets }

    func count(_ zone: IntensityZone) -> Int {
        switch zone {
        case .strength:    return strengthSets
        case .hypertrophy: return hypertrophySets
        case .endurance:   return enduranceSets
        }
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Rep-range distribution of completed `.reps` sets over the
    /// trailing `window` (default 4 weeks) as of `now`.
    func intensityMix(
        window: TimeInterval = 28 * 86_400,
        now: Date = Date()
    ) -> IntensityMix {
        let cutoff = now.addingTimeInterval(-window)
        var strength = 0, hypertrophy = 0, endurance = 0

        for session in self {
            let date = session.completedAt ?? session.startedAt
            guard date > cutoff else { continue }
            for exercise in session.exercises
            where exercise.modality == .dynamicStrength && exercise.trackingMode == .reps {
                for set in exercise.sets where set.isAnalyticsEligible && set.reps > 0 {
                    switch IntensityZone.zone(forReps: set.reps) {
                    case .strength:    strength += 1
                    case .hypertrophy: hypertrophy += 1
                    case .endurance:   endurance += 1
                    }
                }
            }
        }

        return IntensityMix(
            strengthSets: strength,
            hypertrophySets: hypertrophy,
            enduranceSets: endurance
        )
    }

    /// Zone counts per calendar week over the trailing `weeks`
    /// (default 12) as of `now`, chronological ascending. Buckets by
    /// the same locale-aware week start `repRangeMigration` uses so
    /// the two reads always agree.
    func weeklyIntensity(weeks: Int = 12, now: Date = Date()) -> [IntensityWeek] {
        let calendar = Calendar.current
        let cutoff = now.addingTimeInterval(-Double(weeks) * 7 * 86_400)
        let currentWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        )

        var byWeek: [Date: (strength: Int, hypertrophy: Int, endurance: Int)] = [:]

        for session in self {
            let date = session.completedAt ?? session.startedAt
            guard date >= cutoff else { continue }
            guard let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            ) else { continue }

            for exercise in session.exercises
            where exercise.modality == .dynamicStrength && exercise.trackingMode == .reps {
                for set in exercise.sets where set.isAnalyticsEligible && set.reps > 0 {
                    var bucket = byWeek[weekStart] ?? (0, 0, 0)
                    switch IntensityZone.zone(forReps: set.reps) {
                    case .strength:    bucket.strength += 1
                    case .hypertrophy: bucket.hypertrophy += 1
                    case .endurance:   bucket.endurance += 1
                    }
                    byWeek[weekStart] = bucket
                }
            }
        }

        return byWeek.keys.sorted().map { weekStart in
            let bucket = byWeek[weekStart] ?? (0, 0, 0)
            return IntensityWeek(
                weekStart: weekStart,
                strengthSets: bucket.strength,
                hypertrophySets: bucket.hypertrophy,
                enduranceSets: bucket.endurance,
                isCurrentWeek: weekStart == currentWeekStart
            )
        }
    }
}

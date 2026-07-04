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
//  Counts completed `.reps` sets over a rolling window (4 weeks by
//  default, to read CURRENT emphasis). Timed holds carry no reps and
//  are excluded. Pure value-type computation on injected dates (see
//  `IntensityMixTests`).
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
            for exercise in session.exercises where exercise.trackingMode == .reps {
                for set in exercise.sets where set.isCompleted && set.reps > 0 {
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
}

//
//  ExerciseLoad.swift
//  vivobody
//
//  Defines how logged resistance combines with body weight. Explicit
//  load modes prevent assisted movements from being treated as though
//  more assistance were more resistance, and let non-comparable work
//  opt out of load-based analytics entirely.
//

import Foundation

/// How an exercise's logged weight contributes to effective resistance.
nonisolated enum ExerciseLoadMode: String, Codable, Hashable, CaseIterable, Sendable {
    /// Logged weight is the complete external resistance.
    case external
    /// A share of body weight plus any added external resistance.
    case bodyweightAdded
    /// A share of body weight minus logged machine assistance.
    case assistanceSubtracted
    /// Resistance cannot be compared consistently (for example bands).
    case nonComparable

    nonisolated var displayName: String {
        switch self {
        case .external: return "External Load"
        case .bodyweightAdded: return "Bodyweight + Load"
        case .assistanceSubtracted: return "Bodyweight − Assistance"
        case .nonComparable: return "Non-comparable"
        }
    }

    nonisolated var supportsLoadComparison: Bool { self != .nonComparable }

    /// User-facing label for the number they enter. The stored field is
    /// always canonical pounds, but its meaning differs materially by
    /// movement: added load and machine assistance must never be called
    /// generic “weight.”
    nonisolated var inputLabel: String {
        switch self {
        case .external: return "Weight"
        case .bodyweightAdded: return "Added load"
        case .assistanceSubtracted: return "Assistance"
        case .nonComparable: return "Resistance"
        }
    }

    /// Compact semantic representation of the raw value the user
    /// entered. This intentionally does not substitute effective load;
    /// it explains whether the number is weight, load added to body
    /// weight, or assistance subtracted from it.
    nonisolated func loggedLoadLabel(
        _ weight: Double,
        unit: WeightUnit,
        includeUnit: Bool
    ) -> String? {
        let formatted = WeightFormatter.string(
            weight,
            unit: unit,
            includeUnit: includeUnit
        )
        switch self {
        case .external:
            return weight > 0 ? formatted : nil
        case .bodyweightAdded:
            return weight > 0 ? "BW + \(formatted)" : "BW"
        case .assistanceSubtracted:
            return weight > 0 ? "\(formatted) assist" : "Unassisted"
        case .nonComparable:
            return weight > 0 ? formatted : nil
        }
    }

    nonisolated var inputOperatorSymbol: String {
        switch self {
        case .assistanceSubtracted: return "−"
        case .nonComparable: return "·"
        case .external, .bodyweightAdded: return "+"
        }
    }
}

/// A snapshottable load interpretation for one exercise.
nonisolated struct ExerciseLoadProfile: Hashable, Sendable {
    let mode: ExerciseLoadMode
    let bodyweightFraction: Double

    nonisolated init(mode: ExerciseLoadMode, bodyweightFraction: Double) {
        self.mode = mode
        self.bodyweightFraction = max(0, min(bodyweightFraction, 1))
    }

    /// Effective resistance in canonical pounds, or nil when this
    /// exercise intentionally opts out of load comparison.
    nonisolated func effectiveLoad(
        loggedWeight: Double,
        bodyweight: Double
    ) -> Double? {
        let loggedWeight = max(0, loggedWeight)

        switch mode {
        case .external:
            return loggedWeight
        case .bodyweightAdded:
            guard bodyweight.isFinite, bodyweight > 0 else { return nil }
            let carriedBodyweight = bodyweight * bodyweightFraction
            return carriedBodyweight + loggedWeight
        case .assistanceSubtracted:
            guard bodyweight.isFinite, bodyweight > 0 else { return nil }
            let carriedBodyweight = bodyweight * bodyweightFraction
            return max(0, carriedBodyweight - loggedWeight)
        case .nonComparable:
            return nil
        }
    }

    /// Relative resistance marker for comparing two sets that share the
    /// same exercise snapshot. It intentionally omits body weight: that
    /// constant cancels within one session. Use this only to choose a
    /// representative set or compare actual vs planned when absolute
    /// effective load is unavailable—never for PRs, tonnage, or e1RM.
    nonisolated func withinSnapshotLoadMarker(loggedWeight: Double) -> Double? {
        let loggedWeight = max(0, loggedWeight)
        switch mode {
        case .external, .bodyweightAdded:
            return loggedWeight
        case .assistanceSubtracted:
            return -loggedWeight
        case .nonComparable:
            return nil
        }
    }

    /// Actual-minus-planned resistance within one unchanged load
    /// snapshot. Bodyweight-added work is `actual - planned`; assisted
    /// work reverses polarity to `planned assistance - actual`.
    nonisolated func withinSnapshotLoadDelta(
        actualLoggedWeight: Double,
        plannedLoggedWeight: Double
    ) -> Double? {
        guard
            let actual = withinSnapshotLoadMarker(loggedWeight: actualLoggedWeight),
            let planned = withinSnapshotLoadMarker(loggedWeight: plannedLoggedWeight)
        else { return nil }
        return actual - planned
    }
}

nonisolated enum ExerciseLoad {
    /// Persisted sentinel for a body weight that is not known yet.
    /// Zero is deliberately not a physiological estimate: load profiles
    /// that depend on body weight return nil until a real measurement is
    /// available, while ordinary external resistance remains usable.
    static let unknownBodyweight: Double = 0

    /// Load semantics resolved case-insensitively from the bundled
    /// catalog. Unknown custom exercises use ordinary external load.
    static func profile(forExerciseNamed name: String) -> ExerciseLoadProfile {
        guard let record = CatalogData.record(forExerciseNamed: name) else {
            return ExerciseLoadProfile(mode: .external, bodyweightFraction: 0)
        }
        return ExerciseLoadProfile(
            mode: record.loadMode,
            bodyweightFraction: record.bodyweightFraction
        )
    }

    static func mode(forExerciseNamed name: String) -> ExerciseLoadMode {
        profile(forExerciseNamed: name).mode
    }

    static func bodyweightFraction(forExerciseNamed name: String) -> Double {
        profile(forExerciseNamed: name).bodyweightFraction
    }
}

/// How a valid performance advanced the standing record. The same value
/// drives live celebration wording and chronological history flags.
nonisolated enum StrengthRecordAdvancement: Hashable, Sendable {
    case load
    case repetitions
    case duration
}

nonisolated enum StrengthPerformanceMetricKind: Hashable, Sendable {
    case load
    case duration
}

/// One transparent performance record. Dynamic-strength and eligible
/// power sets compare effective resistance, then reps at the same load.
/// Comparable isometrics compare effective resistance, then duration;
/// non-comparable isometrics compare duration alone. This deliberately
/// avoids an estimated-1RM formula—the values are the load, reps, and
/// time the user actually logged.
nonisolated enum StrengthPerformance: Hashable, Sendable {
    case dynamic(effectiveLoad: Double, reps: Int)
    case isometric(effectiveLoad: Double? = nil, duration: TimeInterval)

    /// Build a record value from the already-resolved semantic kind.
    /// Callers supply effective load from the exercise's own historical
    /// load profile; unknown bodyweight therefore stays nil here.
    static func make(
        kind: PerformanceSemanticKind,
        effectiveLoad: Double?,
        reps: Int,
        duration: TimeInterval
    ) -> StrengthPerformance? {
        switch kind {
        case .dynamicLoadAndReps, .powerLoadAndReps:
            return makeDynamic(effectiveLoad: effectiveLoad, reps: reps)
        case .isometricLoadAndDuration:
            return makeIsometric(
                effectiveLoad: effectiveLoad,
                comparesLoad: true,
                duration: duration
            )
        case .isometricDuration:
            return makeIsometric(duration: duration)
        case .unrankedReps, .unrankedDuration:
            return nil
        }
    }

    static func makeDynamic(effectiveLoad: Double?, reps: Int) -> StrengthPerformance? {
        guard let effectiveLoad, effectiveLoad > 0, reps > 0 else { return nil }
        return .dynamic(effectiveLoad: effectiveLoad, reps: reps)
    }

    static func makeIsometric(
        effectiveLoad: Double? = nil,
        comparesLoad: Bool = false,
        duration: TimeInterval
    ) -> StrengthPerformance? {
        guard duration > 0 else { return nil }
        if comparesLoad {
            guard let effectiveLoad,
                  effectiveLoad.isFinite,
                  effectiveLoad > 0 else { return nil }
            return .isometric(effectiveLoad: effectiveLoad, duration: duration)
        }
        return .isometric(duration: duration)
    }

    /// Whether this performance establishes a new record over another
    /// performance of the same kind. Different kinds never compare.
    func beats(_ other: StrengthPerformance) -> Bool {
        switch (self, other) {
        case let (.dynamic(load, reps), .dynamic(otherLoad, otherReps)):
            if load == otherLoad { return reps > otherReps }
            return load > otherLoad
        case let (
            .isometric(effectiveLoad, duration),
            .isometric(otherEffectiveLoad, otherDuration)
        ):
            switch (effectiveLoad, otherEffectiveLoad) {
            case let (.some(load), .some(otherLoad)):
                if load == otherLoad { return duration > otherDuration }
                return load > otherLoad
            case (nil, nil):
                return duration > otherDuration
            default:
                // Loaded-comparable and duration-only holds are distinct
                // semantic series and must never establish records over
                // one another.
                return false
            }
        default:
            return false
        }
    }

    /// The shared first-record policy: the first valid performance is a
    /// record. Later performances must beat the standing performance of
    /// the same semantic kind. The returned axis explains what changed.
    func advancement(over previous: StrengthPerformance?) -> StrengthRecordAdvancement? {
        guard let previous else {
            switch self {
            case .dynamic:
                return .load
            case .isometric(.some, _):
                return .load
            case .isometric(nil, _):
                return .duration
            }
        }
        guard beats(previous) else { return nil }

        switch (self, previous) {
        case let (.dynamic(load, _), .dynamic(otherLoad, _)):
            return load > otherLoad ? .load : .repetitions
        case let (
            .isometric(load, _),
            .isometric(otherLoad, _)
        ):
            if let load, let otherLoad, load > otherLoad { return .load }
            return .duration
        default:
            return nil
        }
    }

    /// Leading comparison axis for formatting a standing performance.
    /// Loaded-comparable isometrics are load records first; duration is
    /// their tie-breaker. Duration-only isometrics remain time records.
    var primaryMetric: Double {
        switch self {
        case let .dynamic(effectiveLoad, _): return effectiveLoad
        case let .isometric(.some(effectiveLoad), _): return effectiveLoad
        case let .isometric(nil, duration): return duration
        }
    }

    var primaryMetricKind: StrengthPerformanceMetricKind {
        switch self {
        case .dynamic, .isometric(.some, _): return .load
        case .isometric(nil, _): return .duration
        }
    }

    var dynamicLoadAndReps: (load: Double, reps: Int)? {
        guard case let .dynamic(load, reps) = self else { return nil }
        return (load, reps)
    }

    var isometricLoadAndDuration: (load: Double?, duration: TimeInterval)? {
        guard case let .isometric(load, duration) = self else { return nil }
        return (load, duration)
    }
}

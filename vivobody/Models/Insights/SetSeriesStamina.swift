//
//  SetSeriesStamina.swift
//  vivobody
//
//  Ordered equal-weight working-set runs, with explicit effort ambiguity.
//  Retention describes logged reps; it never diagnoses fatigue or recovery.
//  Same-load trends match exercise, resistance semantics, bodyweight when
//  relevant, first reps, first RIR, and run length across the entire archive.
//

import Foundation

nonisolated struct StaminaSeries: Identifiable, Hashable {
    let id: String
    let date: Date
    let historyKey: String
    let name: String
    let pattern: MovementPattern?
    let loadProfile: ExerciseLoadProfile
    let bodyweight: Double
    let weight: Double
    let reps: [Int]
    let rir: [Int?]
    let heldBackIndices: Set<Int>

    var retention: Double {
        Double(reps.last ?? 0) / Double(reps.first ?? 1)
    }

    var isHeldBack: Bool {
        !heldBackIndices.isEmpty
    }

    var hasUnratedSets: Bool {
        rir.contains(nil)
    }

    struct ComparisonKey: Hashable {
        let historyKey: String
        let loadProfile: ExerciseLoadProfile
        let weight: Double
        let bodyweight: Double
        let count: Int
        let firstReps: Int
        let firstRIR: Int?
        let fullyRated: Bool
    }

    var comparisonKey: ComparisonKey? {
        guard !isHeldBack, loadProfile.mode != .nonComparable else { return nil }
        let usesBodyweight = loadProfile.mode == .bodyweightAdded || loadProfile.mode == .assistanceSubtracted
        guard !usesBodyweight || bodyweight > 0 else { return nil }
        return ComparisonKey(
            historyKey: historyKey, loadProfile: loadProfile,
            weight: weight, bodyweight: usesBodyweight ? bodyweight : 0,
            count: reps.count, firstReps: reps.first ?? 0,
            firstRIR: rir.first ?? nil, fullyRated: !hasUnratedSets
        )
    }
}

nonisolated struct ExerciseStamina: Hashable {
    let series: [StaminaSeries]
    var latest: StaminaSeries? {
        series.last
    }

    /// Show the latest run's matched history; never silently switch loads.
    var trend: [StaminaSeries] {
        guard let key = latest?.comparisonKey else { return [] }
        return series.filter { $0.comparisonKey == key }
    }
}

nonisolated struct SetSeriesStamina {
    struct Pattern: Identifiable {
        let pattern: MovementPattern
        let series: [StaminaSeries]
        let retention: Double
        let change: Double?
        let matchedComparisons: Int
        var id: MovementPattern {
            pattern
        }
    }

    let series: [StaminaSeries]
    let patterns: [Pattern]
    let heldBackCount: Int
    let unratedCount: Int
    let unclassifiedCount: Int

    var byExercise: [String: ExerciseStamina] {
        Dictionary(grouping: series, by: \.historyKey).mapValues { ExerciseStamina(series: $0) }
    }

    static func make(series: [StaminaSeries], now: Date) -> SetSeriesStamina {
        let history = series.filter { $0.date <= now }
        let included = history.filter { !$0.isHeldBack }
        let patterns = MovementPattern.allCases.compactMap { pattern -> Pattern? in
            let values = included.filter { $0.pattern == pattern }
            guard !values.isEmpty else { return nil }
            let comparison = matchedChange(series.filter { $0.pattern == pattern }, now: now)
            return Pattern(
                pattern: pattern, series: values,
                retention: mean(values.map(\.retention)), change: comparison.change,
                matchedComparisons: comparison.count
            )
        }
        return SetSeriesStamina(
            series: history, patterns: patterns,
            heldBackCount: history.count(where: \.isHeldBack),
            unratedCount: included.count(where: \.hasUnratedSets),
            unclassifiedCount: included.count { $0.pattern == nil }
        )
    }

    /// First-to-latest recorded dates at exactly matched prescriptions.
    /// Multiple runs on either endpoint date contribute their mean retention.
    /// Unmatched changes in the mix of exercises cannot create a trend.
    static func matchedChange(_ series: [StaminaSeries], now: Date) -> (change: Double?, count: Int) {
        var matched: [StaminaSeries.ComparisonKey: [StaminaSeries]] = [:]
        for run in series where run.date <= now {
            guard let key = run.comparisonKey else { continue }
            matched[key, default: []].append(run)
        }
        let differences = matched.values.compactMap { runs -> Double? in
            guard let first = runs.map(\.date).min(), let last = runs.map(\.date).max(),
                  first < last else { return nil }
            let baseline = runs.filter { $0.date == first }.map(\.retention)
            let latest = runs.filter { $0.date == last }.map(\.retention)
            return mean(latest) - mean(baseline)
        }
        return (differences.isEmpty ? nil : mean(differences), differences.count)
    }

    private static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(max(1, values.count))
    }
}

nonisolated extension AnalyticsAccumulator {
    func staminaSeries(now: Date, isCancelled: @Sendable () -> Bool = { false }) -> [StaminaSeries] {
        var result: [StaminaSeries] = []
        for session in sessions where session.isCompleted && session.date <= now {
            guard !isCancelled() else { break }
            for (index, replay) in session.exercises.enumerated() {
                result += StaminaRunBuilder.runs(
                    exercise: replay.exercise, date: session.date,
                    identity: "\(session.session.id):\(index)"
                )
            }
        }
        return result.enumerated().sorted {
            $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date
        }.map(\.element)
    }
}

private nonisolated enum StaminaRunBuilder {
    static func runs(exercise: AnalyticsExerciseSnapshot, date: Date, identity: String) -> [StaminaSeries] {
        guard exercise.modality == .dynamicStrength, exercise.trackingMode == .reps else { return [] }
        var runs: [StaminaSeries] = []
        var pending: [AnalyticsSetSnapshot] = []
        var start = 0
        for (index, set) in exercise.sets.enumerated() {
            let valid = set.isCompleted && set.reps > 0 && set.weight.isFinite && set.weight >= 0
            if !valid || pending.first.map({ $0.weight != set.weight }) == true {
                append(pending, exercise: exercise, date: date, id: "\(identity):\(start)", to: &runs)
                pending = []
            }
            if valid {
                if pending.isEmpty { start = index }
                pending.append(set)
            }
        }
        append(pending, exercise: exercise, date: date, id: "\(identity):\(start)", to: &runs)
        return runs
    }

    private static func append(
        _ sets: [AnalyticsSetSnapshot], exercise: AnalyticsExerciseSnapshot,
        date: Date, id: String, to runs: inout [StaminaSeries]
    ) {
        guard sets.count >= 3, let first = sets.first else { return }
        let rir = sets.map { $0.rirLogged ? $0.repsInReserve : nil }
        var minimumRIR: Int?
        var heldBack: Set<Int> = []
        for (index, rating) in rir.enumerated() {
            guard let rating else { continue }
            if let earlier = minimumRIR, rating > earlier { heldBack.insert(index) }
            minimumRIR = min(minimumRIR ?? rating, rating)
        }
        runs.append(StaminaSeries(
            id: id, date: date, historyKey: exercise.historyKey, name: exercise.name,
            pattern: exercise.classification?.pattern, loadProfile: exercise.loadProfile,
            bodyweight: exercise.bodyweightAtSession, weight: first.weight,
            reps: sets.map(\.reps), rir: rir, heldBackIndices: heldBack
        ))
    }
}

//
//  ExerciseDetailReadModelDerivation.swift
//  vivobody
//
//  Pure performance derivations for ExerciseDetailReadModel: standing-record
//  selection, effective and estimated load, editor seeding, and the shared
//  display/accessibility formatting for representative sets.
//

import Foundation

// MARK: - Derived report construction

extension ExerciseDetailReadModel {
    nonisolated struct RecordSource: Hashable {
        let date: Date
        let loggedWeight: Double
        let effectiveLoad: Double?
        let reps: Int
        let duration: TimeInterval
        let trackingMode: TrackingMode
        let loadMode: ExerciseLoadMode
        let bodyweightFraction: Double
        let bodyweightAtSession: Double
        let tracksResistance: Bool

        init(_ point: ExerciseProgressPoint) {
            date = point.date
            loggedWeight = max(0, point.topWeight)
            effectiveLoad = point.effectiveTopLoad
            reps = point.topReps
            duration = point.topDuration
            trackingMode = point.trackingMode
            loadMode = point.loadMode
            bodyweightFraction = point.bodyweightFraction
            bodyweightAtSession = point.bodyweightAtSession
            tracksResistance = point.performanceSignature.tracksResistance
        }

        init(_ instance: ExerciseHistoryInstance) {
            let set = instance.representativeSet
            date = instance.date
            loggedWeight = max(0, set.weight)
            effectiveLoad = instance.effectiveRepresentativeLoad
            reps = set.reps
            duration = set.duration
            trackingMode = instance.trackingMode
            loadMode = instance.loadMode
            bodyweightFraction = instance.bodyweightFraction
            bodyweightAtSession = instance.bodyweightAtSession
            tracksResistance = instance.performanceSignature.tracksResistance
        }
    }

    @MainActor
    static func recordSource(
        exercise: ExerciseDescriptor,
        history: ExerciseHistorySummary?,
        progress: ExerciseProgress?
    ) -> RecordSource? {
        if let progress {
            let point: ExerciseProgressPoint? = if exercise.supportsPerformanceRecord {
                progress.points.last(where: \.isStrengthPR)
            } else if exercise.trackingMode == .duration {
                progress.points.max { $0.topDuration < $1.topDuration }
            } else if !exercise.tracksResistance {
                progress.points.max { $0.topReps < $1.topReps }
            } else {
                progress.bestWeightPoint
            }
            if let point { return RecordSource(point) }
            return nil
        }
        return history.map { RecordSource($0.mostRecentInstance) }
    }

    @MainActor
    static func bestSet(
        source: RecordSource?,
        exercise: ExerciseDescriptor,
        unit: WeightUnit,
        now: Date,
        calendar: Calendar
    ) -> BestSet {
        guard let source else {
            return BestSet(
                value: "—",
                unit: nil,
                detail: nil,
                date: nil,
                dateText: nil,
                accessibilityLabel: "Best set, not recorded"
            )
        }

        let value: String
        let unitText: String?
        if !exercise.tracksResistance, exercise.trackingMode == .reps {
            value = "\(source.reps)"
            unitText = nil
        } else if exercise.performanceSemanticKind.comparesLoad {
            value = source.loadMode.loggedLoadLabel(
                source.loggedWeight,
                unit: unit,
                includeUnit: false
            ) ?? "—"
            unitText = value == "—" ? nil : unit.symbol
        } else if exercise.trackingMode == .duration {
            value = DurationFormatter.string(source.duration)
            unitText = nil
        } else {
            value = source.loadMode.loggedLoadLabel(
                source.loggedWeight,
                unit: unit,
                includeUnit: false
            ) ?? "—"
            unitText = nil
        }

        let detail: String? = switch exercise.performanceSemanticKind {
        case .dynamicLoadAndReps, .powerLoadAndReps:
            "× \(source.reps)"
        case .isometricLoadAndDuration:
            "× \(DurationFormatter.string(source.duration))"
        case .isometricDuration, .unrankedDuration:
            nil
        case .unrankedReps:
            exercise.tracksResistance ? nil : "reps"
        }
        let relativeDate = RelativeDate.short(
            source.date,
            now: now,
            calendar: calendar
        )
        let metric = metricText(source: source, unit: unit)
        let accessibility = value == "—"
            ? "Best set unavailable, \(relativeDate)"
            : "Best set, \(metric.accessibilityLabel), \(relativeDate)"
        return BestSet(
            value: value,
            unit: unitText,
            detail: detail,
            date: source.date,
            dateText: relativeDate,
            accessibilityLabel: accessibility
        )
    }

    @MainActor
    static func effectiveLoad(
        exercise: ExerciseDescriptor,
        history: ExerciseHistorySummary?,
        progress: ExerciseProgress?,
        unit: WeightUnit
    ) -> EffectiveLoad? {
        guard history != nil else { return nil }
        guard exercise.loadMode == .bodyweightAdded
            || exercise.loadMode == .assistanceSubtracted else { return nil }

        let source: RecordSource? = if let progress,
                                       let point = progress.points.last(where: \.isStrengthPR)
                                       ?? progress.latest
        {
            RecordSource(point)
        } else {
            history.map { RecordSource($0.mostRecentInstance) }
        }
        guard let source else { return nil }

        let valueText = source.effectiveLoad.map {
            WeightFormatter.string($0, unit: unit)
        } ?? "—"
        let formula = effectiveLoadFormula(source: source, unit: unit)
        let explanation = formula ?? "Body weight unavailable for this session"
        return EffectiveLoad(
            value: source.effectiveLoad,
            valueText: valueText,
            formulaText: formula,
            explanationText: explanation,
            accessibilityLabel: "Effective load, \(valueText). \(explanation)"
        )
    }

    @MainActor
    static func estimatedOneRepMax(
        exercise: ExerciseDescriptor,
        history: ExerciseHistorySummary?,
        progress: ExerciseProgress?
    ) -> Double? {
        guard exercise.supportsEstimatedOneRepMax else { return nil }
        if let progress {
            return progress.bestE1RM > 0 ? progress.bestE1RM : nil
        }
        guard let instance = history?.mostRecentInstance,
              instance.representativeSet.reps > 0,
              let effectiveLoad = instance.effectiveRepresentativeLoad,
              effectiveLoad > 0 else { return nil }
        return effectiveLoad
            * (1 + Double(instance.representativeSet.reps) / 30)
    }

    @MainActor
    static func oneRepMaxSeed(
        exercise: ExerciseDescriptor,
        progress: ExerciseProgress?,
        estimatedOneRepMax: Double?
    ) -> Double {
        if let measured = exercise.measuredOneRepMax { return measured }
        if let estimatedOneRepMax { return estimatedOneRepMax }
        if let progress, progress.bestWeight > 0 { return progress.bestWeight }
        let seed = ExerciseLoadProfile(
            mode: exercise.loadMode,
            bodyweightFraction: exercise.bodyweightFraction
        ).effectiveLoad(
            loggedWeight: exercise.defaultLoggedWeight,
            bodyweight: exercise.currentBodyweight
        )
        return seed.flatMap { $0 > 0 ? $0 : nil } ?? 0
    }

    @MainActor
    static func metricText(
        source: RecordSource,
        unit: WeightUnit
    ) -> MetricText {
        let display: String
        switch source.trackingMode {
        case .reps:
            let load = source.loadMode.summaryLoadLabel(
                source.loggedWeight,
                unit: unit
            )
            display = load.map { "\($0) × \(source.reps)" }
                ?? "\(source.reps) reps"
        case .duration:
            let duration = DurationFormatter.string(source.duration)
            let load = source.loadMode.summaryLoadLabel(
                source.loggedWeight,
                unit: unit
            )
            display = load.map { "\($0) × \(duration)" } ?? duration
        }
        return MetricText(
            display: display,
            accessibilityLabel: metricAccessibilityLabel(
                source: source,
                unit: unit
            )
        )
    }

    @MainActor
    static func metricAccessibilityLabel(
        source: RecordSource,
        unit: WeightUnit
    ) -> String {
        let base: String = switch source.trackingMode {
        case .reps:
            "\(source.reps) \(source.reps == 1 ? "rep" : "reps")"
        case .duration:
            durationAccessibilityLabel(source.duration)
        }
        guard source.tracksResistance,
              let load = source.loadMode.accessibilityLoadDescription(
                  source.loggedWeight,
                  unit: unit
              ) else { return base }
        return "\(base) \(load)"
    }

    @MainActor
    static func effectiveLoadFormula(
        source: RecordSource,
        unit: WeightUnit
    ) -> String? {
        guard source.bodyweightAtSession.isFinite,
              source.bodyweightAtSession > 0 else { return nil }
        let bodyweight = WeightFormatter.string(
            source.bodyweightAtSession,
            unit: unit,
            fractionDigits: 1
        )
        let logged = WeightFormatter.string(
            source.loggedWeight,
            unit: unit
        )
        let percent = Int((source.bodyweightFraction * 100).rounded())
        return switch source.loadMode {
        case .bodyweightAdded:
            "\(bodyweight) BW × \(percent)% + \(logged)"
        case .assistanceSubtracted:
            "\(bodyweight) BW × \(percent)% − \(logged)"
        case .external, .nonComparable:
            nil
        }
    }

    static func durationAccessibilityLabel(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        if minutes == 0 {
            return "\(seconds) \(seconds == 1 ? "second" : "seconds")"
        }
        let minuteText = "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
        guard seconds > 0 else { return minuteText }
        return "\(minuteText) and \(seconds) \(seconds == 1 ? "second" : "seconds")"
    }
}

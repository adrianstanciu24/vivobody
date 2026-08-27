//
//  ExerciseReceiptSemantics.swift
//  vivobody
//
//  Load-aware workout performance, receipt, and normalization semantics.
//

import Foundation

extension Exercise {
    /// Clear legacy or stale pound values from a fixture with no resistance
    /// axis. Archived history remains immutable and is interpreted instead.
    @discardableResult
    func normalizeUntrackedResistance() -> Bool {
        guard !tracksResistance else { return false }
        var changed = false
        if plannedWeight != 0 {
            plannedWeight = 0
            changed = true
        }
        for set in sets {
            if set.weight != 0 {
                set.weight = 0
                changed = true
            }
            if set.plannedWeight != 0 {
                set.plannedWeight = 0
                changed = true
            }
        }
        return changed
    }

    var loadBodyweight: Double {
        let value = session?.bodyweightAtStart ?? ExerciseLoad.unknownBodyweight
        return value.isFinite && value > 0 ? value : ExerciseLoad.unknownBodyweight
    }

    func effectiveLoad(loggedWeight: Double) -> Double? {
        loadProfile.effectiveLoad(
            loggedWeight: loggedWeight,
            bodyweight: loadBodyweight
        )
    }

    var representativeTopSet: WorkoutSet? {
        sets.filter(\.isAnalyticsEligible).max(by: isOrderedBeforeForRepresentativeSet)
    }

    private func isOrderedBeforeForRepresentativeSet(
        _ lhs: WorkoutSet,
        _ rhs: WorkoutSet
    ) -> Bool {
        let leftPerformance = strengthPerformance(for: lhs)
        let rightPerformance = strengthPerformance(for: rhs)
        switch (leftPerformance, rightPerformance) {
        case let (.some(left), .some(right)):
            return right.beats(left)
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        case (nil, nil):
            break
        }

        if performanceSemanticKind.comparesLoad,
           let leftMarker = loadProfile.withinSnapshotLoadMarker(loggedWeight: lhs.weight),
           let rightMarker = loadProfile.withinSnapshotLoadMarker(loggedWeight: rhs.weight),
           leftMarker != rightMarker
        {
            return leftMarker < rightMarker
        }

        switch trackingMode {
        case .reps:
            if lhs.reps == rhs.reps { return lhs.weight < rhs.weight }
            return lhs.reps < rhs.reps
        case .duration:
            if lhs.duration == rhs.duration { return lhs.weight < rhs.weight }
            return lhs.duration < rhs.duration
        }
    }

    func strengthPerformance(for set: WorkoutSet) -> StrengthPerformance? {
        guard set.isAnalyticsEligible else { return nil }
        switch performanceSemanticKind {
        case .dynamicLoadAndReps, .powerLoadAndReps:
            return StrengthPerformance.makeDynamic(
                effectiveLoad: effectiveLoad(loggedWeight: set.weight),
                reps: set.reps
            )
        case .isometricLoadAndDuration:
            return StrengthPerformance.makeIsometric(
                effectiveLoad: effectiveLoad(loggedWeight: set.weight),
                comparesLoad: true,
                duration: set.duration
            )
        case .isometricDuration:
            return StrengthPerformance.makeIsometric(duration: set.duration)
        case .unrankedReps, .unrankedDuration:
            return nil
        }
    }

    var bestStrengthPerformance: StrengthPerformance? {
        sets.compactMap(strengthPerformance(for:)).reduce(nil as StrengthPerformance?) {
            best, candidate in
            guard let best else { return candidate }
            return candidate.beats(best) ? candidate : best
        }
    }

    var completedHardSetCount: Int {
        guard modality.supportsHardSetAnalytics else { return 0 }
        switch (modality, trackingMode) {
        case (.dynamicStrength, .reps):
            return sets.count(where: { $0.isAnalyticsEligible && $0.reps > 0 })
        case (.isometricStrength, .duration):
            return sets.count(where: { $0.isAnalyticsEligible && $0.duration > 0 })
        default:
            return 0
        }
    }

    var completedComparableTonnage: Double? {
        guard modality.supportsComparableTonnage(
            for: trackingMode,
            loadMode: loadMode
        ) else { return nil }
        let completed = sets.filter { $0.isAnalyticsEligible && $0.reps > 0 }
        guard !completed.isEmpty else { return 0 }

        var total = 0.0
        for set in completed {
            guard let effectiveLoad = effectiveLoad(loggedWeight: set.weight) else {
                return nil
            }
            total += effectiveLoad * Double(set.reps)
        }
        return total
    }

    var completedReceiptTonnage: Double? {
        if loadMode != .nonComparable { return completedComparableTonnage }
        guard tracksResistance,
              modality == .dynamicStrength,
              trackingMode == .reps
        else { return nil }
        let completed = sets.filter { $0.isAnalyticsEligible && $0.reps > 0 }
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { total, set in
            total + max(0, set.weight) * Double(set.reps)
        }
    }

    var supportsReceiptTonnage: Bool {
        if loadMode == .nonComparable {
            return tracksResistance
                && modality == .dynamicStrength
                && trackingMode == .reps
        }
        return modality.supportsComparableTonnage(
            for: trackingMode,
            loadMode: loadMode
        )
    }

    var hasCompletedReceiptTonnageWork: Bool {
        supportsReceiptTonnage && sets.contains { set in
            set.isAnalyticsEligible && set.reps > 0
        }
    }

    var comparableTonnageSummary: ComparableTonnageSummary {
        guard modality.supportsComparableTonnage(
            for: trackingMode,
            loadMode: loadMode
        ) else { return .zero }
        let hasCompletedReps = sets.contains { $0.isAnalyticsEligible && $0.reps > 0 }
        guard hasCompletedReps else { return .zero }
        guard let tonnage = completedComparableTonnage else {
            return ComparableTonnageSummary(
                knownSubtotal: 0,
                availability: .unavailable
            )
        }
        return ComparableTonnageSummary(
            knownSubtotal: tonnage,
            availability: .complete
        )
    }
}

extension WorkoutSession {
    /// Whether this workout owns a meaningful resistance-volume axis.
    var hasReceiptTonnageAxis: Bool {
        exercises.contains(where: \.hasCompletedReceiptTonnageWork)
    }

    @discardableResult
    func normalizeUntrackedResistance() -> Bool {
        exercises.reduce(false) { changed, exercise in
            exercise.normalizeUntrackedResistance() || changed
        }
    }
}

extension [WorkoutSession] {
    var comparableTonnageSummary: ComparableTonnageSummary {
        reduce(.zero) { summary, session in
            summary.merging(session.comparableTonnageSummary)
        }
    }
}

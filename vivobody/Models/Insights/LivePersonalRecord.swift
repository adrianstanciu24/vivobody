//
//  LivePersonalRecord.swift
//  vivobody
//
//  Pure live-workout personal-record classification. A tap-time candidate
//  freezes exercise identity and performance semantics, then compares only
//  with a known archived history snapshot and completed in-session work.
//

import Foundation

/// Immutable performance evidence captured when the user taps Complete set.
/// Identity and load semantics stay frozen even though the live models can
/// continue changing while the acknowledgement animation runs.
nonisolated struct LivePersonalRecordCandidate: Hashable {
    let exerciseName: String
    let historyKey: String
    let modality: ExerciseModality
    let performanceKind: PerformanceSemanticKind
    let loadProfile: ExerciseLoadProfile
    let bodyweight: Double
    let loggedWeight: Double
    let repetitions: Int
    let duration: TimeInterval
    let priorInSessionPerformances: [StrengthPerformance]

    init(
        exerciseName: String,
        catalogItemID: UUID?,
        catalogID: String?,
        performanceSignature: ExercisePerformanceSignature,
        loadProfile: ExerciseLoadProfile,
        bodyweight: Double,
        loggedWeight: Double,
        repetitions: Int,
        duration: TimeInterval,
        priorInSessionPerformances: [StrengthPerformance]
    ) {
        self.exerciseName = exerciseName
        historyKey = ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: catalogItemID,
            name: exerciseName,
            performanceSignature: performanceSignature
        )
        modality = performanceSignature.modality
        performanceKind = performanceSignature.performanceKind
        self.loadProfile = loadProfile
        self.bodyweight = bodyweight
        self.loggedWeight = loggedWeight
        self.repetitions = repetitions
        self.duration = duration
        self.priorInSessionPerformances = priorInSessionPerformances
    }

    var effectiveLoad: Double? {
        guard performanceKind.comparesLoad else { return nil }
        return loadProfile.effectiveLoad(
            loggedWeight: loggedWeight,
            bodyweight: bodyweight
        )
    }

    var performance: StrengthPerformance? {
        StrengthPerformance.make(
            kind: performanceKind,
            effectiveLoad: effectiveLoad,
            reps: repetitions,
            duration: duration
        )
    }
}

/// A valid candidate that advances the user's standing performance record.
/// Presentation chooses the displayed value and copy from the advancement;
/// the model retains the exact comparable performance that earned it.
nonisolated struct LivePersonalRecord: Hashable {
    let advancement: StrengthRecordAdvancement
    let performance: StrengthPerformance

    /// Unknown history deliberately suppresses a celebration. A known empty
    /// dictionary, by contrast, applies the shared first-valid-performance
    /// policy and can produce the user's first record for this exercise.
    static func evaluate(
        _ candidate: LivePersonalRecordCandidate,
        history: [String: ExerciseHistorySummary]?
    ) -> LivePersonalRecord? {
        guard candidate.performanceKind.supportsRecord,
              let history,
              let performance = candidate.performance
        else { return nil }

        let archivedPrior = history[candidate.historyKey]?
            .allTimeBest(for: candidate.performanceKind)
        let priorBest = bestPerformance(
            archivedPrior: archivedPrior,
            inSession: candidate.priorInSessionPerformances
        )
        guard let advancement = performance.advancement(over: priorBest) else {
            return nil
        }
        return LivePersonalRecord(
            advancement: advancement,
            performance: performance
        )
    }

    private static func bestPerformance(
        archivedPrior: StrengthPerformance?,
        inSession: [StrengthPerformance]
    ) -> StrengthPerformance? {
        ([archivedPrior].compactMap(\.self) + inSession).reduce(
            nil as StrengthPerformance?
        ) { best, candidate in
            guard let best else { return candidate }
            return candidate.beats(best) ? candidate : best
        }
    }
}

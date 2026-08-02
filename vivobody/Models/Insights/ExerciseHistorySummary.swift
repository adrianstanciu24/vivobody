//
//  ExerciseHistorySummary.swift
//  vivobody
//
//  Builds the shared per-exercise history index used by live PR
//  detection and workout-start prefill. One archive pass retains the
//  standing record, latest logged prescription, distinct session
//  count, estimated-strength readiness dates, and latest performance
//  date so hot paths never query and rescan every historical Exercise
//  independently.
//

import Foundation

/// One logged set detached from SwiftData and safe to reuse as the
/// starting prescription for a new workout draft.
nonisolated struct ExerciseSetPrescription: Hashable, Sendable {
    let weight: Double
    let reps: Int
    let duration: TimeInterval
}

/// The latest qualifying occurrence of an exercise in workout history.
/// `setPrescription` preserves the full archived set structure for a
/// fresh start; `completedSetPrescription` is the safe source for
/// overriding a saved template's working values.
nonisolated struct ExerciseHistoryInstance: Hashable, Sendable {
    let date: Date
    let performanceSignature: ExercisePerformanceSignature
    let setPrescription: [ExerciseSetPrescription]
    let completedSetPrescription: [ExerciseSetPrescription]
    let representativeSet: ExerciseSetPrescription
    let representativePerformance: StrengthPerformance?
    let trackingMode: TrackingMode
    let loadMode: ExerciseLoadMode
    let bodyweightFraction: Double
    let bodyweightAtSession: Double
    let effectiveRepresentativeLoad: Double?

    var performanceSemanticKind: PerformanceSemanticKind {
        performanceSignature.performanceKind
    }
}

/// Everything latency-sensitive consumers need for one stable exercise
/// identity. Bundled and name-only identities can outlive classification
/// edits, so record bests are retained per semantic kind and latest
/// prescriptions per exact performance signature.
nonisolated struct ExerciseHistorySummary: Hashable, Sendable {
    let mostRecentInstance: ExerciseHistoryInstance
    let sessionCount: Int
    let latestPerformanceDate: Date
    /// One date per workout that supplied a confidence-eligible e1RM
    /// sample. Exercise Detail uses this even when only one sample exists;
    /// the chart-oriented `ExerciseProgress` collection starts at two.
    let estimatedOneRepMaxDates: [Date]

    private let allTimeBests: [PerformanceSemanticKind: StrengthPerformance]
    private let mostRecentInstancesBySignature:
        [ExercisePerformanceSignature: ExerciseHistoryInstance]

    /// The standing record under the most recently logged semantics.
    var currentAllTimeBest: StrengthPerformance? {
        allTimeBest(for: mostRecentInstance.performanceSemanticKind)
    }

    func allTimeBest(
        for semanticKind: PerformanceSemanticKind
    ) -> StrengthPerformance? {
        allTimeBests[semanticKind]
    }

    /// Exact-signature lookup used by template prefill. This prevents a
    /// newer reclassification from hiding an older compatible instance.
    func mostRecentInstance(
        matching signature: ExercisePerformanceSignature
    ) -> ExerciseHistoryInstance? {
        mostRecentInstancesBySignature[signature]
    }

    /// Compatibility view for picker/detail consumers that already read
    /// `LastExerciseInstance` from SessionAnalytics.
    var lastExerciseInstance: LastExerciseInstance? {
        let instance = mostRecentInstance
        let top = instance.representativeSet
        let isBest = instance.representativePerformance != nil
            && instance.representativePerformance == currentAllTimeBest
        return LastExerciseInstance(
            topWeight: top.weight,
            topReps: top.reps,
            topDuration: top.duration,
            trackingMode: instance.trackingMode,
            loadMode: instance.loadMode,
            bodyweightFraction: instance.bodyweightFraction,
            bodyweightAtSession: instance.bodyweightAtSession,
            effectiveTopLoad: instance.effectiveRepresentativeLoad,
            sessionDate: instance.date,
            isAllTimeBest: isBest
        )
    }

    fileprivate init(
        mostRecentInstance: ExerciseHistoryInstance,
        sessionCount: Int,
        latestPerformanceDate: Date,
        estimatedOneRepMaxDates: [Date],
        allTimeBests: [PerformanceSemanticKind: StrengthPerformance],
        mostRecentInstancesBySignature:
            [ExercisePerformanceSignature: ExerciseHistoryInstance]
    ) {
        self.mostRecentInstance = mostRecentInstance
        self.sessionCount = sessionCount
        self.latestPerformanceDate = latestPerformanceDate
        self.estimatedOneRepMaxDates = estimatedOneRepMaxDates
        self.allTimeBests = allTimeBests
        self.mostRecentInstancesBySignature = mostRecentInstancesBySignature
    }
}

private nonisolated struct ExerciseHistoryBuilder {
    var mostRecentInstance: ExerciseHistoryInstance?
    var latestPerformanceDate: Date = .distantPast
    var allTimeBests: [PerformanceSemanticKind: StrengthPerformance] = [:]
    var mostRecentInstancesBySignature:
        [ExercisePerformanceSignature: ExerciseHistoryInstance] = [:]
    var sessionIDs: Set<UUID> = []
    var estimatedOneRepMaxDatesBySessionID: [UUID: Date] = [:]

    mutating func add(
        _ instance: ExerciseHistoryInstance,
        sessionID: UUID,
        hasEstimatedOneRepMax: Bool
    ) {
        sessionIDs.insert(sessionID)
        if hasEstimatedOneRepMax {
            estimatedOneRepMaxDatesBySessionID[sessionID] = instance.date
        }
        if instance.date > latestPerformanceDate {
            latestPerformanceDate = instance.date
        }
        if mostRecentInstance == nil
            || mostRecentInstance!.date < instance.date {
            mostRecentInstance = instance
        }

        let signature = instance.performanceSignature
        if mostRecentInstancesBySignature[signature] == nil
            || mostRecentInstancesBySignature[signature]!.date < instance.date {
            mostRecentInstancesBySignature[signature] = instance
        }

        guard let performance = instance.representativePerformance else {
            return
        }
        let kind = instance.performanceSemanticKind
        if let best = allTimeBests[kind] {
            if performance.beats(best) {
                allTimeBests[kind] = performance
            }
        } else {
            allTimeBests[kind] = performance
        }
    }

    func build() -> ExerciseHistorySummary? {
        guard let mostRecentInstance else { return nil }
        return ExerciseHistorySummary(
            mostRecentInstance: mostRecentInstance,
            sessionCount: sessionIDs.count,
            latestPerformanceDate: latestPerformanceDate,
            estimatedOneRepMaxDates:
                estimatedOneRepMaxDatesBySessionID.values.sorted(),
            allTimeBests: allTimeBests,
            mostRecentInstancesBySignature: mostRecentInstancesBySignature
        )
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Build every exercise summary in one pass over the shared replay.
    /// Only instances with at least one completed set are history; an
    /// archived but untouched exercise cannot seed a workout or a PR.
    func exerciseHistoryByExercise(
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [String: ExerciseHistorySummary] {
        var builders: [String: ExerciseHistoryBuilder] = [:]

        sessionReplay: for replay in sessions {
            guard !isCancelled() else { return [:] }
            for exerciseReplay in replay.exercises {
                guard !isCancelled() else { break sessionReplay }
                let exercise = exerciseReplay.exercise
                let completedSets = exercise.sets.filter(\.isAnalyticsEligible)
                guard
                    !completedSets.isEmpty,
                    let representative = exercise.representativeTopSet
                else { continue }

                let signature = ExercisePerformanceSignature(
                    modality: exercise.modality,
                    trackingMode: exercise.trackingMode,
                    loadMode: exercise.loadMode,
                    bodyweightFraction: exercise.bodyweightFraction
                )
                let instance = ExerciseHistoryInstance(
                    date: replay.date,
                    performanceSignature: signature,
                    setPrescription: exercise.sets.map(\.prescription),
                    completedSetPrescription: completedSets.map(\.prescription),
                    representativeSet: representative.prescription,
                    representativePerformance: exercise.bestStrengthPerformance,
                    trackingMode: exercise.trackingMode,
                    loadMode: exercise.loadMode,
                    bodyweightFraction: exercise.bodyweightFraction,
                    bodyweightAtSession: exercise.bodyweightAtSession,
                    effectiveRepresentativeLoad:
                        exercise.performanceSemanticKind.comparesLoad
                            ? exercise.effectiveLoad(
                                loggedWeight: representative.weight
                            )
                            : nil
                )
                builders[exercise.historyKey, default: ExerciseHistoryBuilder()]
                    .add(
                        instance,
                        sessionID: replay.session.id,
                        hasEstimatedOneRepMax:
                            exercise.bestEstimatedOneRepMaxSample != nil
                    )
            }
        }

        var result: [String: ExerciseHistorySummary] = [:]
        result.reserveCapacity(builders.count)
        for (key, builder) in builders {
            guard !isCancelled() else { return [:] }
            result[key] = builder.build()
        }
        return result
    }
}

private nonisolated extension AnalyticsSetSnapshot {
    var prescription: ExerciseSetPrescription {
        ExerciseSetPrescription(
            weight: weight,
            reps: reps,
            duration: duration
        )
    }
}

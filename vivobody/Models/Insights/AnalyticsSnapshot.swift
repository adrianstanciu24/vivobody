//
//  AnalyticsSnapshot.swift
//  vivobody
//
//  Immutable, Sendable copies of the SwiftData workout graph used by
//  analytics. The app builds this graph on the main actor while model
//  relationships are valid, then sends only these value types to the
//  background analytics worker. Report code must never retain or cross
//  an actor boundary with WorkoutSession, Exercise, WorkoutSet, or a
//  ModelContext.
//

import Foundation

/// The complete input to one analytics generation. Input order is
/// intentionally preserved here; AnalyticsAccumulator performs the one
/// canonical chronological sort before any report construction.
nonisolated struct AnalyticsSnapshot {
    let sessions: [AnalyticsSessionSnapshot]

    nonisolated init(sessions: [AnalyticsSessionSnapshot]) {
        self.sessions = sessions
    }

    /// Copy every analytics-relevant value while SwiftData models are
    /// still confined to the main actor. Relationship ordering is made
    /// explicit because SwiftData arrays do not guarantee it.
    @MainActor
    init(sessions: [WorkoutSession]) {
        self.sessions = sessions.map(AnalyticsSessionSnapshot.init)
    }
}

/// One workout detached from SwiftData.
nonisolated struct AnalyticsSessionSnapshot {
    /// The persistent session identity, carried so archive-level
    /// reports (e.g. PR-session membership) can be joined back to the
    /// live rows a screen is showing.
    let id: UUID
    let startedAt: Date
    let completedAt: Date?
    let bodyweightAtStart: Double
    let exercises: [AnalyticsExerciseSnapshot]

    nonisolated var date: Date {
        completedAt ?? startedAt
    }

    nonisolated var isCompleted: Bool {
        completedAt != nil
    }

    nonisolated var totalCompletedSets: Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.lazy.filter(\.isCompleted).count
        }
    }

    @MainActor
    init(_ session: WorkoutSession) {
        let bodyweight = session.bodyweightAtStart
        let sanitizedBodyweight = bodyweight.isFinite && bodyweight > 0
            ? bodyweight
            : ExerciseLoad.unknownBodyweight

        id = session.id
        startedAt = session.startedAt
        completedAt = session.completedAt
        bodyweightAtStart = sanitizedBodyweight
        exercises = session.orderedExercises.map { exercise in
            AnalyticsExerciseSnapshot(
                exercise,
                bodyweightAtSession: sanitizedBodyweight
            )
        }
    }

    nonisolated init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date?,
        bodyweightAtStart: Double,
        exercises: [AnalyticsExerciseSnapshot]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.bodyweightAtStart = bodyweightAtStart
        self.exercises = exercises
    }
}

/// One logged exercise detached from its model and owning session.
/// Resolved identity, anatomy, and classification are captured here so
/// background work never consults the mutable catalog or model graph.
nonisolated struct AnalyticsExerciseSnapshot {
    let catalogID: String?
    let familyID: String?
    let catalogItemID: UUID?
    let name: String
    let group: MuscleGroup
    let trackingMode: TrackingMode
    let modality: ExerciseModality
    let loadProfile: ExerciseLoadProfile
    let bodyweightAtSession: Double
    let historyKey: String
    let classification: ExerciseClassification?
    let volumeCredits: [Muscle: Double]
    let sets: [AnalyticsSetSnapshot]

    nonisolated var loadMode: ExerciseLoadMode {
        loadProfile.mode
    }

    nonisolated var bodyweightFraction: Double {
        loadProfile.bodyweightFraction
    }

    nonisolated var tracksResistance: Bool {
        ExerciseResistanceCapability.tracksResistance(
            loadMode: loadMode,
            equipment: classification?.equipment
        )
    }

    nonisolated var loadBodyweight: Double {
        bodyweightAtSession
    }

    nonisolated var performanceSemanticKind: PerformanceSemanticKind {
        modality.performanceSemanticKind(
            for: trackingMode,
            loadMode: loadMode
        )
    }

    @MainActor
    init(_ exercise: Exercise, bodyweightAtSession: Double) {
        catalogID = exercise.catalogID
        familyID = exercise.familyID
        catalogItemID = exercise.catalogItemID
        name = exercise.name
        group = exercise.group
        trackingMode = exercise.trackingMode
        modality = exercise.modality
        loadProfile = exercise.loadProfile
        self.bodyweightAtSession = bodyweightAtSession
        historyKey = exercise.historyKey
        classification = exercise.classification
        volumeCredits = exercise.muscleInvolvement.volumeCredits.filter {
            $0.value > 0
        }
        sets = exercise.orderedSets.map {
            AnalyticsSetSnapshot(
                $0,
                tracksResistance: exercise.tracksResistance
            )
        }
    }

    nonisolated init(
        catalogID: String?,
        familyID: String? = nil,
        catalogItemID: UUID?,
        name: String,
        group: MuscleGroup,
        trackingMode: TrackingMode,
        modality: ExerciseModality,
        loadProfile: ExerciseLoadProfile,
        bodyweightAtSession: Double,
        historyKey: String,
        classification: ExerciseClassification?,
        volumeCredits: [Muscle: Double],
        sets: [AnalyticsSetSnapshot]
    ) {
        self.catalogID = catalogID
        self.familyID = familyID
        self.catalogItemID = catalogItemID
        self.name = name
        self.group = group
        self.trackingMode = trackingMode
        self.modality = modality
        self.loadProfile = loadProfile
        self.bodyweightAtSession = bodyweightAtSession
        self.historyKey = historyKey
        self.classification = classification
        self.volumeCredits = volumeCredits
        self.sets = sets
    }

    nonisolated func effectiveLoad(loggedWeight: Double) -> Double? {
        loadProfile.effectiveLoad(
            loggedWeight: loggedWeight,
            bodyweight: bodyweightAtSession
        )
    }

    /// Shared record value for a completed set under this exercise's
    /// snapshotted performance semantics.
    nonisolated func strengthPerformance(
        for set: AnalyticsSetSnapshot
    ) -> StrengthPerformance? {
        guard set.isAnalyticsEligible else { return nil }

        return StrengthPerformance.make(
            kind: performanceSemanticKind,
            effectiveLoad: performanceSemanticKind.comparesLoad
                ? effectiveLoad(loggedWeight: set.weight)
                : nil,
            reps: set.reps,
            duration: set.duration
        )
    }

    /// Best completed record performance for this exercise under its
    /// snapshotted semantic kind — the snapshot twin of
    /// `Exercise.bestStrengthPerformance`, so PR-session membership
    /// computed off the model graph matches the live detector.
    nonisolated var bestStrengthPerformance: StrengthPerformance? {
        sets.lazy
            .compactMap { strengthPerformance(for: $0) }
            .reduce(nil as StrengthPerformance?) { best, candidate in
                guard let best else { return candidate }
                return candidate.beats(best) ? candidate : best
            }
    }

    /// Strongest confidence-eligible Epley estimate in this session.
    /// This is intentionally independent of `representativeTopSet`:
    /// record/history selection compares actual load then reps, whereas
    /// an estimated-1RM curve must maximize the estimate itself.
    nonisolated var bestEstimatedOneRepMaxSample: EstimatedOneRepMaxSample? {
        guard modality.supportsEstimatedOneRepMax(
            for: trackingMode,
            loadMode: loadMode
        ) else { return nil }

        var best: EstimatedOneRepMaxSample?
        for set in sets where set.isAnalyticsEligible {
            guard let effectiveLoad = effectiveLoad(loggedWeight: set.weight),
                  let value = EstimatedOneRepMaxPolicy.estimate(
                      effectiveLoad: effectiveLoad,
                      reps: set.reps
                  )
            else {
                continue
            }
            let candidate = EstimatedOneRepMaxSample(
                value: value,
                effectiveLoad: effectiveLoad,
                reps: set.reps
            )
            guard let standing = best else {
                best = candidate
                continue
            }
            if candidate.value > standing.value + 1e-9
                || (abs(candidate.value - standing.value) <= 1e-9
                    && candidate.reps < standing.reps)
            {
                best = candidate
            }
        }
        return best
    }

    /// The same modality/load-aware representative used by history and
    /// progress before the model graph is discarded.
    nonisolated var representativeTopSet: AnalyticsSetSnapshot? {
        sets.filter(\.isAnalyticsEligible).max(by: isOrderedBeforeForRepresentativeSet)
    }

    private nonisolated func isOrderedBeforeForRepresentativeSet(
        _ lhs: AnalyticsSetSnapshot,
        _ rhs: AnalyticsSetSnapshot
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
           let leftMarker = loadProfile.withinSnapshotLoadMarker(
               loggedWeight: lhs.weight
           ),
           let rightMarker = loadProfile.withinSnapshotLoadMarker(
               loggedWeight: rhs.weight
           ),
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

    /// Completed working sets eligible for strength-set analytics.
    nonisolated var completedHardSetCount: Int {
        switch (modality, trackingMode) {
        case (.dynamicStrength, .reps):
            sets.lazy.count(where: {
                $0.isAnalyticsEligible && $0.reps > 0
            })
        case (.isometricStrength, .duration):
            sets.lazy.count(where: {
                $0.isAnalyticsEligible && $0.duration > 0
            })
        default:
            0
        }
    }

    /// Completeness-aware comparable tonnage used by progress points.
    nonisolated var comparableTonnageSummary: ComparableTonnageSummary {
        guard modality.supportsComparableTonnage(
            for: trackingMode,
            loadMode: loadMode
        ) else {
            return .zero
        }

        let completed = sets.filter {
            $0.isAnalyticsEligible && $0.reps > 0
        }
        guard !completed.isEmpty else { return .zero }

        var tonnage = 0.0
        for set in completed {
            guard let effectiveLoad = effectiveLoad(loggedWeight: set.weight) else {
                return ComparableTonnageSummary(
                    knownSubtotal: 0,
                    availability: .unavailable
                )
            }
            tonnage += effectiveLoad * Double(set.reps)
        }
        return ComparableTonnageSummary(
            knownSubtotal: tonnage,
            availability: .complete
        )
    }
}

/// One logged set detached from SwiftData. Planned targets and model IDs
/// are omitted because no SessionAnalytics report reads them.
nonisolated struct AnalyticsSetSnapshot {
    let weight: Double
    let reps: Int
    let duration: TimeInterval
    let isCompleted: Bool
    let repsInReserve: Int
    let rirLogged: Bool

    nonisolated var isAnalyticsEligible: Bool {
        isCompleted
    }

    @MainActor
    init(_ set: WorkoutSet, tracksResistance: Bool = true) {
        weight = tracksResistance ? max(0, set.weight) : 0
        reps = set.reps
        duration = set.duration
        isCompleted = set.isCompleted
        repsInReserve = set.repsInReserve
        rirLogged = set.rirLogged
    }

    nonisolated init(
        weight: Double,
        reps: Int,
        duration: TimeInterval,
        isCompleted: Bool,
        repsInReserve: Int,
        rirLogged: Bool
    ) {
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.isCompleted = isCompleted
        self.repsInReserve = repsInReserve
        self.rirLogged = rirLogged
    }
}

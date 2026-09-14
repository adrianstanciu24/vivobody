//
//  AntagonistBalance.swift
//  vivobody
//
//  The symmetry instrument for the Insights tab. It judges opposing
//  muscles and movement patterns against each other: mechanic-separated
//  push/pull, directional compound push/pull, lower-body muscle pairs,
//  squat/hinge, biceps/triceps, and bilateral/unilateral work.
//
//  All comparisons share the `SetStimulus` hard-set currency
//  across all recorded history. Muscle comparisons retain role-based
//  involvement credit; movement comparisons count each exercise's
//  whole stimulus once.
//
//  All pairs remain present so the UI can preview every comparison;
//  pairs need six effective sets across at least two workouts before
//  they receive a verdict; earlier reads remain in a building state. Pure
//  value type on injected dates, so it's testable on a virtual clock
//  (see `AntagonistBalanceTests`).
//

import Foundation

private nonisolated enum SymmetryMovementBucket: Hashable {
    case compoundPush
    case compoundPull
    case isolationPush
    case isolationPull
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case squat
    case hinge
    case bilateral
    case unilateral

    static func buckets(for classification: ExerciseClassification) -> [Self] {
        var buckets = [
            broadBucket(for: classification),
            directionalBucket(for: classification),
        ].compactMap(\.self)
        buckets.append(classification.laterality == .bilateral ? .bilateral : .unilateral)
        return buckets
    }

    private static func broadBucket(for classification: ExerciseClassification) -> Self? {
        switch (classification.mechanic, classification.pattern, classification.trainingRole) {
        case (.compound, .push, _): .compoundPush
        case (.compound, .pull, _): .compoundPull
        case (.isolation, _, .push): .isolationPush
        case (.isolation, _, .pull): .isolationPull
        default: nil
        }
    }

    private static func directionalBucket(for classification: ExerciseClassification) -> Self? {
        switch (classification.pattern, classification.direction) {
        case (.push, .horizontal), (.push, .diagonal):
            .horizontalPush
        case (.pull, .horizontal): .horizontalPull
        case (.push, .vertical): .verticalPush
        case (.pull, .vertical): .verticalPull
        case (.squat, _): .squat
        case (.hinge, _): .hinge
        default: nil
        }
    }
}

/// Glanceable comparison buckets aggregate exact regions using the
/// strongest role credit per exercise. Summing every split region would
/// make taxonomy granularity fabricate extra hard sets.
private nonisolated enum SymmetryMuscleBucket: Hashable {
    case biceps, triceps, quads, hamstrings
    case hipAbductors, hipAdductors, calves, shins

    static func bucket(for muscle: Muscle) -> SymmetryMuscleBucket? {
        switch muscle {
        case .bicepsBrachii, .brachialis: .biceps
        case .triceps: .triceps
        case .rectusFemoris, .vasti: .quads
        case .bicepsFemoris, .medialHamstrings: .hamstrings
        case .gluteMed: .hipAbductors
        case .adductorMagnus, .adductorLongusBrevis, .gracilis, .pectineus:
            .hipAdductors
        case .gastrocnemius, .soleus, .flexorHallucisLongus: .calves
        case .tibialisAnterior, .fibularisLongusBrevis, .fibularisTertius,
             .toeExtensors:
            .shins
        default: nil
        }
    }
}

// MARK: - Verdict

nonisolated enum SymmetryVerdict: Hashable {
    case noData
    case balanced
    case leftHeavy
    case rightHeavy
}

/// Some comparisons have a meaningful evenness read. Others simply
/// describe how the user chose to train: squat/hinge,
/// bilateral/unilateral, and roster-limited lower-body region pairs.
/// Descriptive pairs must not imply that 50/50 is a universal target.
nonisolated enum AntagonistComparisonKind: Hashable {
    case balance
    case distribution
}

// MARK: - Pair

nonisolated struct AntagonistPair: Identifiable, Hashable {
    /// Stable key (e.g. "compound-push-pull"), also the SwiftUI identity.
    let id: String
    let leftLabel: String
    let rightLabel: String
    let leftSets: Double
    let rightSets: Double
    let comparisonKind: AntagonistComparisonKind
    let sampleSessions: Int

    init(
        id: String,
        leftLabel: String,
        rightLabel: String,
        leftSets: Double,
        rightSets: Double,
        comparisonKind: AntagonistComparisonKind = .balance,
        sampleSessions: Int = AntagonistBoard.minimumSessions
    ) {
        self.id = id
        self.leftLabel = leftLabel
        self.rightLabel = rightLabel
        self.leftSets = leftSets
        self.rightSets = rightSets
        self.comparisonKind = comparisonKind
        self.sampleSessions = sampleSessions
    }

    var total: Double {
        leftSets + rightSets
    }

    /// Fraction of the pair's work carried by the left side, `0...1`
    /// (0.5 is a perfect split).
    var leftShare: Double {
        total > 0 ? leftSets / total : 0.5
    }

    var verdict: SymmetryVerdict {
        guard total >= AntagonistBoard.minSets,
              sampleSessions >= AntagonistBoard.minimumSessions
        else {
            return .noData
        }
        let share = leftShare
        if share > 0.5 + AntagonistBoard.tolerance { return .leftHeavy }
        if share < 0.5 - AntagonistBoard.tolerance { return .rightHeavy }
        return .balanced
    }

    var hasMeaningfulWork: Bool {
        verdict != .noData
    }

    var isBalanced: Bool {
        verdict == .balanced
    }

    var isDescriptive: Bool {
        comparisonKind == .distribution
    }

    /// Distance from a perfect split, `0` (even) … `0.5` (all one side).
    var skew: Double {
        abs(leftShare - 0.5)
    }

    var heavierLabel: String {
        leftShare >= 0.5 ? leftLabel : rightLabel
    }

    var lighterLabel: String {
        leftShare >= 0.5 ? rightLabel : leftLabel
    }
}

// MARK: - Board

nonisolated struct AntagonistBoard {
    /// Within ±this share of 50/50 reads as balanced.
    static let tolerance = 0.10
    /// A pair needs at least this much combined work to be judged.
    static let minSets = 6.0
    /// One workout is an allocation snapshot, not yet a pattern.
    static let minimumSessions = 2

    /// Fixed display order, grouped by broad upper-body balance,
    /// directional balance, lower-body balance, then laterality.
    let pairs: [AntagonistPair]

    var hasAny: Bool {
        pairs.contains { $0.hasMeaningfulWork }
    }

    var imbalancedCount: Int {
        pairs.lazy.count(where: {
            !$0.isDescriptive && $0.hasMeaningfulWork && !$0.isBalanced
        })
    }

    /// The most lopsided pair — drives the headline.
    var worst: AntagonistPair? {
        pairs.filter {
            !$0.isDescriptive && $0.hasMeaningfulWork && !$0.isBalanced
        }.max { $0.skew < $1.skew }
    }

    func pair(_ id: String) -> AntagonistPair? {
        pairs.first { $0.id == id }
    }
}

// MARK: - Aggregation

@MainActor
extension [WorkoutSession] {
    /// Effective-set split for each antagonist pair across all history
    /// through `now`.
    func antagonistBalance(now: Date = Date()) -> AntagonistBoard {
        AnalyticsAccumulator.replay(self).antagonistBalance(now: now)
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Build symmetry from the same priced exercise events used by the
    /// core muscle and load reports.
    func antagonistBalance(
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> AntagonistBoard {
        var muscleSets: [SymmetryMuscleBucket: Double] = [:]
        var movementSets: [SymmetryMovementBucket: Double] = [:]
        var muscleSessions: [SymmetryMuscleBucket: Set<UUID>] = [:]
        var movementSessions: [SymmetryMovementBucket: Set<UUID>] = [:]

        accumulateAntagonistSets(
            through: now,
            muscleSets: &muscleSets,
            movementSets: &movementSets,
            muscleSessions: &muscleSessions,
            movementSessions: &movementSessions,
            isCancelled: isCancelled
        )

        func musclePair(
            _ id: String,
            _ leftLabel: String,
            _ left: SymmetryMuscleBucket,
            _ rightLabel: String,
            _ right: SymmetryMuscleBucket,
            kind: AntagonistComparisonKind = .balance
        ) -> AntagonistPair {
            let sessions = (muscleSessions[left] ?? [])
                .union(muscleSessions[right] ?? [])
            return makePair(
                id: id,
                leftLabel: leftLabel,
                leftSets: muscleSets[left] ?? 0,
                rightLabel: rightLabel,
                rightSets: muscleSets[right] ?? 0,
                kind: kind,
                sampleSessions: sessions.count
            )
        }
        func movementPair(
            _ id: String,
            _ leftLabel: String,
            _ left: SymmetryMovementBucket,
            _ rightLabel: String,
            _ right: SymmetryMovementBucket,
            kind: AntagonistComparisonKind = .balance
        ) -> AntagonistPair {
            makePair(
                id: id,
                leftLabel: leftLabel,
                leftSets: movementSets[left] ?? 0,
                rightLabel: rightLabel,
                rightSets: movementSets[right] ?? 0,
                kind: kind,
                sampleSessions: (movementSessions[left] ?? [])
                    .union(movementSessions[right] ?? [])
                    .count
            )
        }
        func makePair(
            id: String,
            leftLabel: String,
            leftSets: Double,
            rightLabel: String,
            rightSets: Double,
            kind: AntagonistComparisonKind = .balance,
            sampleSessions: Int
        ) -> AntagonistPair {
            AntagonistPair(
                id: id,
                leftLabel: leftLabel,
                rightLabel: rightLabel,
                leftSets: leftSets,
                rightSets: rightSets,
                comparisonKind: kind,
                sampleSessions: sampleSessions
            )
        }

        // Stable order keeps related comparisons adjacent for the
        // grouped Symmetry presentation.
        let pairs: [AntagonistPair] = [
            movementPair(
                "compound-push-pull",
                "Compound Push", .compoundPush,
                "Compound Pull", .compoundPull
            ),
            movementPair(
                "horizontal-push-pull",
                "Horizontal Push", .horizontalPush,
                "Horizontal Pull", .horizontalPull
            ),
            movementPair(
                "vertical-push-pull",
                "Vertical Push", .verticalPush,
                "Vertical Pull", .verticalPull
            ),
            movementPair(
                "isolation-push-pull",
                "Isolation Push", .isolationPush,
                "Isolation Pull", .isolationPull,
                kind: .distribution
            ),
            musclePair(
                "bi-tri",
                "Biceps", .biceps,
                "Triceps", .triceps
            ),
            musclePair(
                "quad-ham",
                "Quads", .quads,
                "Hamstrings", .hamstrings
            ),
            musclePair(
                "hip-abductors-adductors",
                "Hip Abductors", .hipAbductors,
                "Hip Adductors", .hipAdductors,
                kind: .distribution
            ),
            musclePair(
                "calves-shins",
                "Calves", .calves,
                "Shins", .shins,
                kind: .distribution
            ),
            movementPair(
                "squat-hinge",
                "Squat", .squat,
                "Hinge", .hinge,
                kind: .distribution
            ),
            movementPair(
                "bilateral-unilateral",
                "Bilateral", .bilateral,
                "Unilateral", .unilateral,
                kind: .distribution
            ),
        ]

        return AntagonistBoard(pairs: pairs)
    }

    private func accumulateAntagonistSets(
        through now: Date,
        muscleSets: inout [SymmetryMuscleBucket: Double],
        movementSets: inout [SymmetryMovementBucket: Double],
        muscleSessions: inout [SymmetryMuscleBucket: Set<UUID>],
        movementSessions: inout [SymmetryMovementBucket: Set<UUID>],
        isCancelled: @Sendable () -> Bool
    ) {
        sessionLoop: for session in sessions where session.date <= now {
            guard !isCancelled() else { break }
            for exercise in session.exercises where exercise.setEquivalent > 0 {
                guard !isCancelled() else { break sessionLoop }
                accumulateMuscleSymmetry(
                    exercise,
                    sessionID: session.session.id,
                    sets: &muscleSets,
                    sessions: &muscleSessions
                )
                accumulateMovementSymmetry(
                    exercise,
                    sessionID: session.session.id,
                    sets: &movementSets,
                    sessions: &movementSessions
                )
            }
        }
    }

    private func accumulateMuscleSymmetry(
        _ exercise: AnalyticsExerciseReplay,
        sessionID: UUID,
        sets: inout [SymmetryMuscleBucket: Double],
        sessions: inout [SymmetryMuscleBucket: Set<UUID>]
    ) {
        var strongest: [SymmetryMuscleBucket: Double] = [:]
        for (muscle, credit) in exercise.byMuscle {
            guard let bucket = SymmetryMuscleBucket.bucket(for: muscle) else { continue }
            strongest[bucket] = max(strongest[bucket] ?? 0, credit)
        }
        for (bucket, credit) in strongest where credit > 0 {
            sets[bucket, default: 0] += credit
            sessions[bucket, default: []].insert(sessionID)
        }
    }

    private func accumulateMovementSymmetry(
        _ exercise: AnalyticsExerciseReplay,
        sessionID: UUID,
        sets: inout [SymmetryMovementBucket: Double],
        sessions: inout [SymmetryMovementBucket: Set<UUID>]
    ) {
        guard let classification = exercise.classification else { return }
        for bucket in SymmetryMovementBucket.buckets(for: classification) {
            sets[bucket, default: 0] += exercise.setEquivalent
            sessions[bucket, default: []].insert(sessionID)
        }
    }
}

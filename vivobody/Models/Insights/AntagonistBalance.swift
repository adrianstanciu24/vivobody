//
//  AntagonistBalance.swift
//  vivobody
//
//  The symmetry instrument for the Insights tab. It judges opposing
//  muscles and movement patterns against each other: broad push/pull,
//  directional push/pull, lower-body muscle pairs, squat/hinge,
//  biceps/triceps, and bilateral/unilateral work.
//
//  All nine comparisons share the `SetStimulus` hard-set currency
//  over a 4-week window. Muscle comparisons retain role-based
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
    case push
    case pull
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case squat
    case hinge
    case bilateral
    case unilateral
}

/// Glanceable comparison buckets aggregate exact regions using the
/// strongest role credit per exercise. Summing every split region would
/// make taxonomy granularity fabricate extra hard sets.
private nonisolated enum SymmetryMuscleBucket: Hashable {
    case biceps, triceps, quads, hamstrings
    case hipAbductors, hipAdductors, calves, shins

    static func bucket(for muscle: Muscle) -> SymmetryMuscleBucket? {
        switch muscle {
        case .bicepsBrachii, .brachialis: return .biceps
        case .triceps: return .triceps
        case .rectusFemoris, .vasti: return .quads
        case .bicepsFemoris, .medialHamstrings: return .hamstrings
        case .gluteMed: return .hipAbductors
        case .adductorMagnus, .adductorLongusBrevis, .gracilis, .pectineus:
            return .hipAdductors
        case .gastrocnemius, .soleus, .flexorHallucisLongus: return .calves
        case .tibialisAnterior, .fibularisLongusBrevis, .fibularisTertius,
             .toeExtensors:
            return .shins
        default: return nil
        }
    }
}

// MARK: - Verdict

nonisolated enum SymmetryVerdict: Hashable, Sendable {
    case noData
    case balanced
    case leftHeavy
    case rightHeavy
}

/// Some comparisons have a meaningful evenness read. Others simply
/// describe how the user chose to train: squat/hinge,
/// bilateral/unilateral, and roster-limited lower-body region pairs.
/// Descriptive pairs must not imply that 50/50 is a universal target.
nonisolated enum AntagonistComparisonKind: Hashable, Sendable {
    case balance
    case distribution
}

// MARK: - Pair

nonisolated struct AntagonistPair: Identifiable, Hashable, Sendable {
    /// Stable key (e.g. "push-pull"), also the SwiftUI identity.
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

    var total: Double { leftSets + rightSets }

    /// Fraction of the pair's work carried by the left side, `0...1`
    /// (0.5 is a perfect split).
    var leftShare: Double { total > 0 ? leftSets / total : 0.5 }

    var verdict: SymmetryVerdict {
        guard total >= AntagonistBoard.minSets,
              sampleSessions >= AntagonistBoard.minimumSessions else {
            return .noData
        }
        let share = leftShare
        if share > 0.5 + AntagonistBoard.tolerance { return .leftHeavy }
        if share < 0.5 - AntagonistBoard.tolerance { return .rightHeavy }
        return .balanced
    }

    var hasMeaningfulWork: Bool { verdict != .noData }
    var isBalanced: Bool { verdict == .balanced }
    var isDescriptive: Bool { comparisonKind == .distribution }

    /// Distance from a perfect split, `0` (even) … `0.5` (all one side).
    var skew: Double { abs(leftShare - 0.5) }

    var heavierLabel: String { leftShare >= 0.5 ? leftLabel : rightLabel }
    var lighterLabel: String { leftShare >= 0.5 ? rightLabel : leftLabel }
}

// MARK: - Board

nonisolated struct AntagonistBoard: Sendable {
    /// Window over which both sides accumulate work.
    static let windowDays = 28
    /// Within ±this share of 50/50 reads as balanced.
    static let tolerance = 0.10
    /// A pair needs at least this much combined work to be judged.
    static let minSets = 6.0
    /// One workout is an allocation snapshot, not yet a pattern.
    static let minimumSessions = 2

    /// Fixed display order, grouped by broad upper-body balance,
    /// directional balance, lower-body balance, then laterality.
    let pairs: [AntagonistPair]

    var hasAny: Bool { pairs.contains { $0.hasMeaningfulWork } }
    var imbalancedCount: Int {
        pairs.lazy.filter {
            !$0.isDescriptive && $0.hasMeaningfulWork && !$0.isBalanced
        }.count
    }

    /// The most lopsided pair — drives the headline.
    var worst: AntagonistPair? {
        pairs.filter {
            !$0.isDescriptive && $0.hasMeaningfulWork && !$0.isBalanced
        }.max { $0.skew < $1.skew }
    }

    func pair(_ id: String) -> AntagonistPair? { pairs.first { $0.id == id } }
}

// MARK: - Aggregation

@MainActor
extension Array where Element == WorkoutSession {
    /// Effective-set split for each antagonist pair over the trailing
    /// 4 weeks as of `now`.
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
        let cutoff = now.addingTimeInterval(
            -Double(AntagonistBoard.windowDays) * 86_400
        )
        var muscleSets: [SymmetryMuscleBucket: Double] = [:]
        var movementSets: [SymmetryMovementBucket: Double] = [:]
        var muscleSessions: [SymmetryMuscleBucket: Set<UUID>] = [:]
        var movementSessions: [SymmetryMovementBucket: Set<UUID>] = [:]

        sessionLoop: for session in sessions {
            guard !isCancelled() else { break }
            guard session.date <= now else { continue }

            for exercise in session.exercises {
                guard !isCancelled() else { break sessionLoop }
                let stimulus = exercise.setEquivalent
                guard session.date >= cutoff, stimulus > 0 else { continue }

                var strongestCreditByBucket: [SymmetryMuscleBucket: Double] = [:]
                for (muscle, credit) in exercise.byMuscle {
                    guard !isCancelled() else { break sessionLoop }
                    guard let bucket = SymmetryMuscleBucket.bucket(for: muscle) else { continue }
                    strongestCreditByBucket[bucket] = max(
                        strongestCreditByBucket[bucket] ?? 0,
                        credit
                    )
                }
                for (bucket, credit) in strongestCreditByBucket where credit > 0 {
                    muscleSets[bucket, default: 0] += credit
                    muscleSessions[bucket, default: []].insert(session.session.id)
                }

                guard let classification = exercise.classification else {
                    continue
                }
                switch classification.pattern {
                case .push:
                    movementSets[.push, default: 0] += stimulus
                    movementSessions[.push, default: []]
                        .insert(session.session.id)
                case .pull:
                    movementSets[.pull, default: 0] += stimulus
                    movementSessions[.pull, default: []]
                        .insert(session.session.id)
                default:
                    break
                }
                let bucket: SymmetryMovementBucket?
                switch (classification.pattern, classification.direction) {
                case (.push, .horizontal): bucket = .horizontalPush
                // Incline and decline presses retain horizontal-press
                // ancestry even though the catalog now records their
                // more precise diagonal direction.
                case (.push, .diagonal): bucket = .horizontalPush
                case (.pull, .horizontal): bucket = .horizontalPull
                case (.push, .vertical): bucket = .verticalPush
                case (.pull, .vertical): bucket = .verticalPull
                case (.squat, _): bucket = .squat
                case (.hinge, _): bucket = .hinge
                default: bucket = nil
                }
                if let bucket {
                    movementSets[bucket, default: 0] += stimulus
                    movementSessions[bucket, default: []]
                        .insert(session.session.id)
                }

                let laterality: SymmetryMovementBucket =
                    classification.laterality == .bilateral
                    ? .bilateral
                    : .unilateral
                movementSets[laterality, default: 0] += stimulus
                movementSessions[laterality, default: []]
                    .insert(session.session.id)
            }
        }

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
                "push-pull",
                "Push", .push,
                "Pull", .pull
            ),
            movementPair(
                "horizontal-push-pull",
                "Horizontal + Diagonal Push", .horizontalPush,
                "Horizontal Pull", .horizontalPull
            ),
            movementPair(
                "vertical-push-pull",
                "Vertical Push", .verticalPush,
                "Vertical Pull", .verticalPull
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
}

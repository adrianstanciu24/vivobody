//
//  AntagonistBalance.swift
//  vivobody
//
//  The symmetry instrument for the Insights tab. It judges opposing
//  muscles and movement patterns against each other: broad push/pull,
//  directional push/pull, lower-body muscle pairs, squat/hinge,
//  biceps/triceps, and bilateral/unilateral work.
//
//  All nine comparisons share the `SetStimulus` hard-set-equivalent
//  currency over a 4-week window. Muscle comparisons retain role-based
//  involvement credit; movement comparisons count each exercise's
//  whole stimulus once. The archive is replayed chronologically so
//  load references stay causal.
//
//  All pairs remain present so the UI can preview every comparison;
//  pairs with too little work are marked as having no data. Pure
//  value type on injected dates, so it's testable on a virtual clock
//  (see `AntagonistBalanceTests`).
//

import Foundation

private nonisolated enum SymmetryMovementBucket: Hashable {
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case squat
    case hinge
    case bilateral
    case unilateral
}

// MARK: - Verdict

nonisolated enum SymmetryVerdict: Hashable {
    case noData
    case balanced
    case leftHeavy
    case rightHeavy
}

// MARK: - Pair

nonisolated struct AntagonistPair: Identifiable, Hashable {
    /// Stable key (e.g. "push-pull"), also the SwiftUI identity.
    let id: String
    let leftLabel: String
    let rightLabel: String
    let leftSets: Double
    let rightSets: Double

    var total: Double { leftSets + rightSets }

    /// Fraction of the pair's work carried by the left side, `0...1`
    /// (0.5 is a perfect split).
    var leftShare: Double { total > 0 ? leftSets / total : 0.5 }

    var verdict: SymmetryVerdict {
        guard total >= AntagonistBoard.minSets else { return .noData }
        let share = leftShare
        if share > 0.5 + AntagonistBoard.tolerance { return .leftHeavy }
        if share < 0.5 - AntagonistBoard.tolerance { return .rightHeavy }
        return .balanced
    }

    var hasMeaningfulWork: Bool { verdict != .noData }
    var isBalanced: Bool { verdict == .balanced }

    /// Distance from a perfect split, `0` (even) … `0.5` (all one side).
    var skew: Double { abs(leftShare - 0.5) }

    var heavierLabel: String { leftShare >= 0.5 ? leftLabel : rightLabel }
    var lighterLabel: String { leftShare >= 0.5 ? rightLabel : leftLabel }
}

// MARK: - Board

nonisolated struct AntagonistBoard {
    /// Window over which both sides accumulate work.
    static let windowDays = 28
    /// Within ±this share of 50/50 reads as balanced.
    static let tolerance = 0.10
    /// A pair needs at least this much combined work to be judged.
    static let minSets = 1.0

    /// Fixed display order, grouped by broad upper-body balance,
    /// directional balance, lower-body balance, then laterality.
    let pairs: [AntagonistPair]

    var hasAny: Bool { pairs.contains { $0.hasMeaningfulWork } }
    var imbalancedCount: Int {
        pairs.lazy.filter {
            $0.hasMeaningfulWork && !$0.isBalanced
        }.count
    }

    /// The most lopsided pair — drives the headline.
    var worst: AntagonistPair? {
        pairs.filter {
            $0.hasMeaningfulWork && !$0.isBalanced
        }.max { $0.skew < $1.skew }
    }

    func pair(_ id: String) -> AntagonistPair? { pairs.first { $0.id == id } }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Effective-set split for each antagonist pair over the trailing
    /// 4 weeks as of `now`.
    func antagonistBalance(now: Date = Date()) -> AntagonistBoard {
        let cutoff = now.addingTimeInterval(
            -Double(AntagonistBoard.windowDays) * 86_400
        )
        var muscleSets: [Muscle: Double] = [:]
        var movementSets: [SymmetryMovementBucket: Double] = [:]
        var calculator = SetStimulus.Calculator()

        let ordered = sorted {
            ($0.completedAt ?? $0.startedAt) < ($1.completedAt ?? $1.startedAt)
        }

        for session in ordered {
            let date = session.completedAt ?? session.startedAt
            guard date <= now else { continue }

            for exercise in session.orderedExercises {
                // Price the exercise once. Calling both calculator APIs
                // would update its load reference twice and would also
                // risk doubling unilateral work.
                let stimulus = calculator.setEquivalentCredit(
                    for: exercise,
                    at: date
                )
                guard date >= cutoff, stimulus > 0 else { continue }

                for (muscle, credit) in exercise.muscleInvolvement.volumeCredits {
                    muscleSets[muscle, default: 0] += stimulus * credit
                }

                guard let classification = exercise.classification else {
                    continue
                }
                let bucket: SymmetryMovementBucket?
                switch (classification.pattern, classification.direction) {
                case (.push, .horizontal): bucket = .horizontalPush
                case (.pull, .horizontal): bucket = .horizontalPull
                case (.push, .vertical): bucket = .verticalPush
                case (.pull, .vertical): bucket = .verticalPull
                case (.squat, _): bucket = .squat
                case (.hinge, _): bucket = .hinge
                default: bucket = nil
                }
                if let bucket {
                    movementSets[bucket, default: 0] += stimulus
                }

                let laterality: SymmetryMovementBucket =
                    classification.laterality == .bilateral
                    ? .bilateral
                    : .unilateral
                movementSets[laterality, default: 0] += stimulus
            }
        }

        func muscleSum(_ muscles: [Muscle]) -> Double {
            muscles.reduce(0) { $0 + (muscleSets[$1] ?? 0) }
        }
        func musclePair(
            _ id: String,
            _ leftLabel: String,
            _ leftMuscles: [Muscle],
            _ rightLabel: String,
            _ rightMuscles: [Muscle]
        ) -> AntagonistPair {
            makePair(
                id: id,
                leftLabel: leftLabel,
                leftSets: muscleSum(leftMuscles),
                rightLabel: rightLabel,
                rightSets: muscleSum(rightMuscles)
            )
        }
        func movementPair(
            _ id: String,
            _ leftLabel: String,
            _ left: SymmetryMovementBucket,
            _ rightLabel: String,
            _ right: SymmetryMovementBucket
        ) -> AntagonistPair {
            makePair(
                id: id,
                leftLabel: leftLabel,
                leftSets: movementSets[left] ?? 0,
                rightLabel: rightLabel,
                rightSets: movementSets[right] ?? 0
            )
        }
        func makePair(
            id: String,
            leftLabel: String,
            leftSets: Double,
            rightLabel: String,
            rightSets: Double
        ) -> AntagonistPair {
            AntagonistPair(
                id: id,
                leftLabel: leftLabel,
                rightLabel: rightLabel,
                leftSets: leftSets,
                rightSets: rightSets
            )
        }

        // Stable order keeps related comparisons adjacent for the
        // grouped Symmetry presentation.
        let pairs: [AntagonistPair] = [
            musclePair(
                "push-pull",
                "Push", [.pectorals, .deltoids, .triceps],
                "Pull", [.lats, .rhomboids, .traps, .teresMajor, .externalRotators, .biceps]
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
            musclePair(
                "bi-tri",
                "Biceps", [.biceps],
                "Triceps", [.triceps]
            ),
            musclePair(
                "quad-ham",
                "Quads", [.quads],
                "Hamstrings", [.hamstrings]
            ),
            musclePair(
                "hip-abductors-adductors",
                "Hip Abductors", [.gluteMed],
                "Hip Adductors", [.adductors]
            ),
            musclePair(
                "calves-shins",
                "Calves", [.calves],
                "Shins", [.shins]
            ),
            movementPair(
                "squat-hinge",
                "Squat", .squat,
                "Hinge", .hinge
            ),
            movementPair(
                "bilateral-unilateral",
                "Bilateral", .bilateral,
                "Unilateral", .unilateral
            ),
        ]

        return AntagonistBoard(pairs: pairs)
    }
}

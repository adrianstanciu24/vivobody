//
//  AntagonistBalance.swift
//  vivobody
//
//  The symmetry instrument for the Insights tab. The muscle-balance
//  view judges each muscle against its own volume landmark; this
//  judges OPPOSING groups against EACH OTHER — the push/pull,
//  quad/hamstring and biceps/triceps ratios coaches watch because a
//  lopsided one nudges posture and joints toward trouble.
//
//  It reuses the effective-set engine (`muscleVolume`) over a 4-week
//  window — long enough that both sides of a pair have accumulated
//  representative work — then sums each side's graded sets and asks
//  how far the split strays from 50/50.
//
//  Pairs with too little work to judge are dropped. Pure value type
//  on injected dates, so it's testable on a virtual clock (see
//  `AntagonistBalanceTests`).
//

import Foundation

// MARK: - Verdict

nonisolated enum SymmetryVerdict: Hashable {
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
        let share = leftShare
        if share > 0.5 + AntagonistBoard.tolerance { return .leftHeavy }
        if share < 0.5 - AntagonistBoard.tolerance { return .rightHeavy }
        return .balanced
    }

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

    /// Fixed display order: upper body, lower body, arms.
    let pairs: [AntagonistPair]

    var hasAny: Bool { !pairs.isEmpty }
    var imbalancedCount: Int { pairs.lazy.filter { !$0.isBalanced }.count }

    /// The most lopsided pair — drives the headline.
    var worst: AntagonistPair? {
        pairs.filter { !$0.isBalanced }.max { $0.skew < $1.skew }
    }

    func pair(_ id: String) -> AntagonistPair? { pairs.first { $0.id == id } }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Effective-set split for each antagonist pair over the trailing
    /// 4 weeks as of `now`.
    func antagonistBalance(now: Date = Date()) -> AntagonistBoard {
        let stats = muscleVolume(
            window: Double(AntagonistBoard.windowDays) * 86_400,
            now: now
        )
        var sets: [Muscle: Double] = [:]
        for stat in stats { sets[stat.muscle] = stat.effectiveSets }
        func sum(_ muscles: [Muscle]) -> Double {
            muscles.reduce(0) { $0 + (sets[$1] ?? 0) }
        }

        // (id, leftLabel, leftMuscles, rightLabel, rightMuscles)
        let definitions: [(String, String, [Muscle], String, [Muscle])] = [
            ("push-pull", "Push", [.pectorals, .deltoids, .triceps],
             "Pull", [.lats, .rhomboids, .traps, .teres, .biceps]),
            ("quad-ham", "Quads", [.quads],
             "Hamstrings", [.hamstrings]),
            ("bi-tri", "Biceps", [.biceps],
             "Triceps", [.triceps]),
        ]

        let pairs: [AntagonistPair] = definitions.compactMap { def in
            let left = sum(def.2)
            let right = sum(def.4)
            guard left + right >= AntagonistBoard.minSets else { return nil }
            return AntagonistPair(
                id: def.0,
                leftLabel: def.1,
                rightLabel: def.3,
                leftSets: left,
                rightSets: right
            )
        }

        return AntagonistBoard(pairs: pairs)
    }
}

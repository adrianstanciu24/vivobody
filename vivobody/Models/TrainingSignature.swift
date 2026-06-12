//
//  TrainingSignature.swift
//  vivobody
//
//  The Insights capstone — less an instrument than a portrait. Every
//  other section answers a question ("which muscle is behind?", "is
//  this lift climbing?"); this one fuses the whole picture into a
//  single generative emblem you'd recognise as *yours*, the way a
//  fingerprint is yours, and watch morph as your training changes.
//
//  Four signals feed it, each already computed elsewhere on the tab:
//
//    • Volume mix (the balance view) → the angular WIDTH of each of
//      six petals, one per muscle group: where your effective sets
//      actually go.
//    • Development (the momentum model) → the REACH of each petal:
//      how far that region has come.
//    • Effort (consistency / reps-in-reserve) → the emblem's
//      INTENSITY: training near failure burns vivid, easy work
//      reads faint.
//    • Cadence (sessions per week) → a ring of beads around the
//      bloom: how often you show up.
//
//  Pure value type built from the other models' outputs, so the
//  mapping is deterministic and testable (see `TrainingSignatureTests`).
//

import Foundation

// MARK: - Petal

/// One muscle group's contribution to the signature: how much of the
/// recent volume it carries (`volumeShare`) and how developed it is
/// (`development`). The wheel position is fixed by `MuscleGroup`
/// order, so the same training always draws the same shape.
nonisolated struct SignaturePetal: Identifiable, Hashable {
    let group: MuscleGroup
    /// Fraction of the window's total effective sets, `0…1`.
    let volumeShare: Double
    /// Average adaptation across the group's muscles, `0…1`.
    let development: Double

    var id: String { group.rawValue }
}

// MARK: - Signature

nonisolated struct TrainingSignature {
    /// Margin over an even split a region must clear to count as the
    /// signature's lead (rather than reading as balanced).
    static let dominanceMargin = 1.3

    /// Six petals, always in `MuscleGroup.allCases` order.
    let petals: [SignaturePetal]
    /// Effort, `0…1` — derived from average reps-in-reserve (less in
    /// reserve burns brighter). `0.5` when no RIR has been logged.
    let intensity: Double
    /// Recent sessions per week — the cadence halo.
    let cadence: Double
    /// Evenness of the volume spread, `0…1` (1 = perfectly balanced
    /// across every trained region). Normalised entropy of the shares.
    let balance: Double
    /// The region carrying clearly the most volume, when one leads.
    let dominantGroup: MuscleGroup?
    /// Net development trajectory across all trained groups.
    let trend: MomentumTrend
    /// Whether there's any training to draw at all.
    let hasSignature: Bool

    init(
        volume: [MuscleVolumeStat],
        momentum: MuscleMomentumBoard,
        consistency: ConsistencyReport
    ) {
        // Volume share per group (effective sets over the balance window).
        var groupVolume: [MuscleGroup: Double] = [:]
        for stat in volume {
            groupVolume[stat.muscle.group, default: 0] += stat.effectiveSets
        }
        let totalVolume = groupVolume.values.reduce(0, +)

        // Development per group — mean adaptation across the group's
        // muscles that carry a momentum reading.
        let allMomentum = momentum.growing + momentum.holding + momentum.fading
        var devSum: [MuscleGroup: Double] = [:]
        var devCount: [MuscleGroup: Int] = [:]
        for stat in allMomentum {
            devSum[stat.muscle.group, default: 0] += stat.adaptation
            devCount[stat.muscle.group, default: 0] += 1
        }

        petals = MuscleGroup.allCases.map { group in
            let share = totalVolume > 0 ? (groupVolume[group] ?? 0) / totalVolume : 0
            let count = devCount[group] ?? 0
            let dev = count > 0 ? (devSum[group] ?? 0) / Double(count) : 0
            return SignaturePetal(group: group, volumeShare: share, development: dev)
        }

        hasSignature = totalVolume > 0

        // Effort → intensity. RIR runs 0…5; less in reserve is more
        // intense. No logged reps-effort reads as neutral.
        if let rir = consistency.averageRIR {
            intensity = Swift.min(1, Swift.max(0, 1 - rir / 5))
        } else {
            intensity = 0.5
        }

        cadence = consistency.sessionsPerWeek

        // Balance via normalised Shannon entropy of the active shares.
        let shares = petals.map(\.volumeShare).filter { $0 > 0 }
        if shares.count > 1 {
            let entropy = -shares.reduce(0.0) { $0 + $1 * Foundation.log($1) }
            balance = entropy / Foundation.log(Double(shares.count))
        } else {
            balance = 0
        }

        // Dominant region — only when it clears the even-split margin;
        // a single trained region is trivially dominant.
        let active = petals.filter { $0.volumeShare > 0 }
        if active.count == 1 {
            dominantGroup = active.first?.group
        } else if active.count > 1,
                  let top = active.max(by: { $0.volumeShare < $1.volumeShare }) {
            let even = 1.0 / Double(active.count)
            dominantGroup = top.volumeShare >= even * Self.dominanceMargin ? top.group : nil
        } else {
            dominantGroup = nil
        }

        // Net trajectory from the momentum tallies.
        if momentum.growingCount > momentum.fadingCount {
            trend = .growing
        } else if momentum.fadingCount > momentum.growingCount {
            trend = .fading
        } else {
            trend = .holding
        }
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Build the training signature as of `now`, fusing the balance,
    /// momentum, and consistency models.
    func trainingSignature(now: Date = Date()) -> TrainingSignature {
        TrainingSignature(
            volume: muscleVolume(now: now),
            momentum: muscleMomentum(now: now),
            consistency: consistency(now: now)
        )
    }
}

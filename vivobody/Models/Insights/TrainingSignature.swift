//
//  TrainingSignature.swift
//  vivobody
//
//  The Insights capstone — less an instrument than a portrait. It
//  compresses the archive's lifetime allocation into a single
//  generative emblem you'd recognise as *yours*, the way a fingerprint
//  is yours, and watch morph as your training history grows.
//
//  Two lifetime signals feed it:
//
//    • All-time volume mix → the angular WIDTH of each of six
//      petals and their REACH, one per muscle group: where your work
//      has gone across the complete archive.
//    • Lifetime cadence (average sessions per week) → the stat strip's
//      per-week numeral. The bloom's lone orbiting satellite is purely
//      ambient, so the mark carries life without hiding another metric.
//
//  Pure value type built from the other models' outputs, so the
//  mapping is deterministic and testable (see `TrainingSignatureTests`).
//

import Foundation

// MARK: - Petal

/// One muscle group's contribution to the signature: how much of the
/// all-time volume it carries (`volumeShare`). The wheel position is
/// fixed by `MuscleGroup` order, so the same archive always draws the
/// same shape.
nonisolated struct SignaturePetal: Identifiable, Hashable {
    let group: MuscleGroup
    /// Fraction of the archive's total effective sets, `0…1`.
    let volumeShare: Double

    var id: String { group.rawValue }
}

// MARK: - Signature

nonisolated struct TrainingSignature {
    /// Margin over an even split a region must clear to count as the
    /// signature's lead (rather than reading as broad coverage).
    static let dominanceMargin = 1.3
    /// Balance must be genuinely close to a six-way split before the
    /// plain-language read calls the archive evenly spread.
    static let evenBalanceThreshold = 0.9

    /// Six petals, always in `MuscleGroup.allCases` order.
    let petals: [SignaturePetal]
    /// Lifetime average sessions per week, shown beside the bloom.
    let cadence: Double
    /// Evenness of the volume spread, `0…1` (1 = perfectly balanced
    /// across all six regions). Normalised entropy of the shares.
    let balance: Double
    /// Number of the six regions carrying all-time effective volume.
    let trainedGroupCount: Int
    /// Fraction of all six regions carrying all-time effective volume.
    let coverage: Double
    /// The region carrying clearly the most volume, when one leads.
    let dominantGroup: MuscleGroup?
    /// Whether any historical muscle-mapped training exists to draw.
    let hasSignature: Bool
    /// Whether the archive contains any muscle-targeted volume.
    let hasVolume: Bool
    init(
        volume: [MuscleVolumeStat],
        groupVolume authoredGroupVolume: [MuscleGroup: Double]? = nil,
        cadence: Double
    ) {
        // Volume share per group across the full archive. Weekly volume
        // remains available independently on `effectiveSets` for its
        // existing consumers.
        var groupVolume = authoredGroupVolume ?? [:]
        if authoredGroupVolume == nil {
            for stat in volume {
                groupVolume[stat.muscle.group, default: 0] += stat.allTimeEffectiveSets
            }
        }
        let totalVolume = groupVolume.values.reduce(0, +)

        petals = MuscleGroup.allCases.map { group in
            let share = totalVolume > 0 ? (groupVolume[group] ?? 0) / totalVolume : 0
            return SignaturePetal(group: group, volumeShare: share)
        }

        hasVolume = totalVolume > 0
        hasSignature = totalVolume > 0
        trainedGroupCount = groupVolume.values.filter { $0 > 0 }.count
        coverage = Double(trainedGroupCount) / Double(MuscleGroup.allCases.count)

        self.cadence = cadence.isFinite ? Swift.max(0, cadence) : 0

        // Balance via Shannon entropy normalised against all six
        // possible regions. Two evenly trained regions therefore read
        // as good balance within limited coverage, not as 100% global
        // balance.
        let shares = petals.map(\.volumeShare).filter { $0 > 0 }
        if shares.count > 1, MuscleGroup.allCases.count > 1 {
            let entropy = -shares.reduce(0.0) { $0 + $1 * Foundation.log($1) }
            balance = entropy / Foundation.log(Double(MuscleGroup.allCases.count))
        } else {
            balance = 0
        }

        // A region leads only when it is the unique top share and
        // clears the same all-six baseline used by coverage/balance.
        // Equal leaders remain unlabelled instead of being selected by
        // enum ordering.
        let ranked = petals.sorted { $0.volumeShare > $1.volumeShare }
        if let top = ranked.first,
           top.volumeShare >= (1.0 / Double(MuscleGroup.allCases.count)) * Self.dominanceMargin,
           (ranked.dropFirst().first?.volumeShare ?? 0) < top.volumeShare - 1e-9 {
            dominantGroup = top.group
        } else {
            dominantGroup = nil
        }
    }

    /// Plain-language lifetime read used beside the bloom and by the
    /// widget. It intentionally contains no recent-state signal and
    /// treats any non-zero region literally as represented, not as a
    /// claim that the region received substantial work.
    var identityLine: String {
        guard hasSignature else { return "Awaiting training history" }
        let focus: String
        if let dominantGroup {
            focus = "\(dominantGroup.displayName)-led"
        } else if trainedGroupCount == MuscleGroup.allCases.count,
                  balance >= Self.evenBalanceThreshold {
            focus = "Evenly spread"
        } else {
            focus = "No single lead"
        }
        let span: String
        switch trainedGroupCount {
        case 6: span = "all 6 regions"
        case 1: span = "1 region"
        case 2...5: span = "\(trainedGroupCount) regions"
        default: span = "no regions"
        }
        return "\(focus) · \(span)"
    }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Build the lifetime training signature as of `now`.
    func trainingSignature(now: Date = Date()) -> TrainingSignature {
        let archived = filter { $0.completedAt != nil }
        let accumulator = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: archived)
        )
        let progress = accumulator.progressByExercise
        return TrainingSignature(
            volume: accumulator.muscleVolume(now: now),
            groupVolume: accumulator.allTimeMuscleGroupVolume(now: now),
            cadence: accumulator.archiveOverview(
                progress: progress,
                now: now
            ).averageWorkoutsPerWeek
        )
    }
}

nonisolated extension AnalyticsAccumulator {
    /// Group-level hard-set allocation prices each exercise once per
    /// group using its strongest exact-region role. Taxonomy splits
    /// therefore improve anatomical detail without multiplying a
    /// group's Training Signature volume.
    func allTimeMuscleGroupVolume(now: Date) -> [MuscleGroup: Double] {
        var totals: [MuscleGroup: Double] = [:]
        for session in sessions where session.date <= now {
            for exercise in session.exercises {
                var strongestByGroup: [MuscleGroup: Double] = [:]
                for (muscle, credit) in exercise.byMuscle {
                    strongestByGroup[muscle.group] = max(
                        strongestByGroup[muscle.group] ?? 0,
                        credit
                    )
                }
                for (group, credit) in strongestByGroup {
                    totals[group, default: 0] += credit
                }
            }
        }
        return totals
    }
}

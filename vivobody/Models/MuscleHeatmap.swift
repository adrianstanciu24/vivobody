//
//  MuscleHeatmap.swift
//  vivobody
//
//  Turns logged training into per-muscle activation intensities for
//  the 3D body model. Every completed set contributes, but its weight
//  DECAYS with age (14-day exponential half-life), so the figure
//  reads as a map of RECENT emphasis: a muscle you trained hard but
//  have since neglected fades, while freshly-worked muscles glow.
//
//  Formula
//  -------
//    load(set)    = loggedWeight + bodyweightFraction · bodyweight
//    effort(set)  = load · reps              (reps mode)
//                 = load · duration / 30s    (timed-hold mode)
//    score(m)     = recency-decayed Σ of effort · role.weight over
//                   every completed set involving m (primary 1.0,
//                   secondary 0.5), each set fading on a 14-day
//                   half-life.
//    intensity(m) = (score(m) / reference) ^ gamma      gamma = 0.6
//
//  Scoring is by tonnage (load × reps), so heavier work counts more —
//  10×100 kg outweighs 10×1 kg. Unloaded movements still register via
//  their `ExerciseLoad` bodyweight fraction (a push-up ≈ 0.64 × body
//  weight) so they're never zeroed out.
//
//  Normalisation — two half-lives
//  ------------------------------
//  `score(m)` decays FAST (14-day half-life): it tracks how hard a
//  muscle has been worked LATELY. The `reference` it's divided by is
//  a high-water mark of the busiest muscle that decays SLOW (90-day
//  half-life): it remembers "your established training level."
//
//  Dividing fast-by-slow gives two behaviours at once:
//    • Shift focus (train chest, skip legs) → legs fade relative to
//      chest while the reference holds — RELATIVE emphasis.
//    • Stop training everything → every score decays fast while the
//      reference lingers, so the WHOLE body fades to dark over a few
//      weeks — ABSOLUTE fade-to-dark.
//
//  During steady training the reference tracks the busiest muscle, so
//  it still glows full. The gamma < 1 lifts mid-trained muscles out
//  of the floor so the map stays readable. With no logged work the
//  map is empty and every mesh renders at its untrained base tone.
//
//  Output is keyed by BodyModel.scn node name (`Pectoralis_Major_L`,
//  …) so the scene can look up an intensity per mesh directly.
//

import CoreGraphics
import Foundation

enum MuscleHeatmap {
    /// Lifts mid-range intensities upward so moderately-trained
    /// muscles are visibly distinct from untrained ones. < 1.
    private static let gamma = 0.6

    /// One timed-hold second is worth this fraction of a rep when
    /// scoring effort, so a 60s plank ≈ 2 rep-equivalents.
    private static let secondsPerRepEquivalent = 30.0

    /// Days for a muscle's recent-work score to halve. Recent work
    /// dominates; neglected muscles fade smoothly rather than off a
    /// cliff.
    private static let halfLifeDays = 14.0

    /// Days for the normalisation reference (the busiest-muscle high-
    /// water mark) to halve. Much longer than `halfLifeDays`, so the
    /// reference outlives individual sessions and the whole body only
    /// fades to dark after a sustained layoff.
    private static let referenceHalfLifeDays = 90.0

    /// Per-muscle activation in `0...1`. Each muscle's recency-decayed
    /// score is divided by a slow-decaying high-water-mark reference,
    /// so the map shows both relative emphasis AND absolute freshness:
    /// a total training layoff fades everything toward dark. Empty
    /// when nothing has been logged. `bodyweight` (lb) sets the load
    /// for unloaded movements; pass the lifter's latest logged weight,
    /// or rely on the `ExerciseLoad.defaultBodyweight` fallback.
    static func intensities(
        from sessions: [WorkoutSession],
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date()
    ) -> [Muscle: Double] {
        let bw = bodyweight > 0 ? bodyweight : ExerciseLoad.defaultBodyweight

        // Replay sessions oldest→newest, decaying the running scores
        // and the reference between sessions at their own rates.
        let ordered = sessions.sorted {
            ($0.completedAt ?? $0.startedAt) < ($1.completedAt ?? $1.startedAt)
        }

        var score: [Muscle: Double] = [:]
        var reference = 0.0
        var lastDate: Date?

        for session in ordered {
            let date = session.completedAt ?? session.startedAt
            decay(&score, &reference, from: lastDate, to: date)

            for exercise in session.exercises {
                let involvement = exercise.muscleInvolvement
                guard !involvement.primary.isEmpty || !involvement.secondary.isEmpty else { continue }

                let effort = completedEffort(for: exercise, bodyweight: bw)
                guard effort > 0 else { continue }

                for muscle in involvement.primary {
                    score[muscle, default: 0] += effort * MuscleRole.primary.weight
                }
                for muscle in involvement.secondary {
                    score[muscle, default: 0] += effort * MuscleRole.secondary.weight
                }
            }

            reference = max(reference, score.values.max() ?? 0)
            lastDate = date
        }

        // Fade from the last logged session up to the present moment.
        decay(&score, &reference, from: lastDate, to: now)

        guard reference > 0 else { return [:] }
        return score.mapValues { min(1.0, pow(max(0, $0) / reference, gamma)) }
    }

    /// Advances the running scores (fast half-life) and the reference
    /// (slow half-life) forward in time. No-op for the first session.
    private static func decay(
        _ score: inout [Muscle: Double],
        _ reference: inout Double,
        from start: Date?,
        to end: Date
    ) {
        guard let start else { return }
        let days = max(0, end.timeIntervalSince(start)) / 86_400
        guard days > 0 else { return }

        let scoreFactor = pow(0.5, days / halfLifeDays)
        for key in score.keys { score[key]! *= scoreFactor }
        reference *= pow(0.5, days / referenceHalfLifeDays)
    }

    /// Per-mesh intensities keyed by BodyModel.scn node name. Each
    /// muscle paints all of its `_L`/`_R` meshes at the same value.
    static func nodeIntensities(
        from sessions: [WorkoutSession],
        bodyweight: Double = ExerciseLoad.defaultBodyweight,
        now: Date = Date()
    ) -> [String: CGFloat] {
        let perMuscle = intensities(from: sessions, bodyweight: bodyweight, now: now)
        var result: [String: CGFloat] = [:]
        for (muscle, value) in perMuscle {
            let intensity = CGFloat(value)
            for node in muscle.nodeNames {
                result[node] = intensity
            }
        }
        return result
    }

    /// Summed effort (tonnage) of an exercise's completed sets.
    /// Effective load adds the exercise's bodyweight share to the
    /// logged weight, so unloaded and loaded work share one scale.
    private static func completedEffort(for exercise: Exercise, bodyweight: Double) -> Double {
        let completed = exercise.sets.filter(\.isCompleted)
        let bodyweightLoad = ExerciseLoad.bodyweightFraction(forExerciseNamed: exercise.name) * bodyweight

        switch exercise.trackingMode {
        case .reps:
            return completed.reduce(0) { $0 + ($1.weight + bodyweightLoad) * Double($1.reps) }
        case .duration:
            return completed.reduce(0) { $0 + ($1.weight + bodyweightLoad) * ($1.duration / secondsPerRepEquivalent) }
        }
    }
}

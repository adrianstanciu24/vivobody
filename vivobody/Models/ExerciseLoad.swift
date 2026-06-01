//
//  ExerciseLoad.swift
//  vivobody
//
//  The bodyweight-load fraction for each exercise — the slice of the
//  lifter's own body weight a movement carries. It exists so the
//  muscle heatmap can score work as `load × reps` (tonnage) without
//  zeroing out unloaded movements: a push-up logs `weight = 0`, but
//  it still moves ~64% of bodyweight, so its effective load is
//  `0.64 × bodyweight`.
//
//  Effective load for a set is therefore:
//      load = loggedWeight + fraction × bodyweight
//  which also makes weighted bodyweight work fall out correctly — a
//  "+25" weighted pull-up becomes `bodyweight + 25`.
//
//  Pure machine / barbell / dumbbell lifts carry none of the lifter's
//  weight, so their fraction is 0 (the default for any name not in
//  the table) and `load` collapses to just the logged weight.
//
//  Fractions are rough biomechanical estimates — exact values don't
//  matter much because the heatmap normalises relative to the
//  busiest muscle; what matters is that unloaded work registers in
//  the right ballpark against loaded work.
//

import Foundation

enum ExerciseLoad {
    /// Fallback body weight (lb) when the user has never logged one.
    /// ~70 kg — a reasonable adult default so bodyweight movements
    /// still score on a fresh install.
    static let defaultBodyweight: Double = 155

    /// The share of body weight an exercise carries, resolved by name
    /// (case-insensitive). 0 for fully-loaded lifts (the default).
    static func bodyweightFraction(forExerciseNamed name: String) -> Double {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return fractions[key] ?? 0
    }

    /// Keyed by lowercased exercise name. Only the bodyweight-based
    /// seeds appear; everything else defaults to 0.
    private static let fractions: [String: Double] = {
        let pairs: [(String, Double)] = [
            // Chest
            ("Push-Up", 0.64),
            ("Dip", 0.95),
            // Back
            ("Pull-Up", 1.0),
            ("Chin-Up", 1.0),
            ("Neutral-Grip Pull-Up", 1.0),
            ("Weighted Pull-Up", 1.0),
            ("Dead Hang", 1.0),
            // Arms
            ("Close-Grip Push-Up", 0.64),
            // Legs
            ("Wall Sit", 0.5),
            // Core
            ("Plank", 0.6),
            ("Side Plank", 0.55),
            ("Hollow Hold", 0.3),
            ("L-Sit", 0.7),
            ("Hanging Leg Raise", 0.5),
            ("Hanging Knee Raise", 0.4),
            ("Ab Wheel Rollout", 0.5),
            ("Dead Bug", 0.15),
            ("Bird Dog", 0.2),
        ]
        return Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.lowercased(), $0.1) })
    }()
}

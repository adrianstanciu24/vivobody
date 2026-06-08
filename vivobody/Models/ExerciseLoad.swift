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
    /// (case-insensitive) from the bundled catalog (`CatalogData`). 0
    /// for fully-loaded lifts and any name the catalog never shipped.
    static func bodyweightFraction(forExerciseNamed name: String) -> Double {
        CatalogData.record(forExerciseNamed: name)?.bodyweightFractionValue ?? 0
    }
}

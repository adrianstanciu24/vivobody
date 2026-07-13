//
//  SessionAnalytics.swift
//  vivobody
//
//  Shared cache for all session-derived analytics. Keyed by a
//  dataset fingerprint (session count + newest completedAt) so
//  every report computes at most once per data change, not once
//  per render. Held on AppState so both TodayScreen and
//  InsightsScreen share the same cache — switching tabs is free.
//
//  Replaces the ad-hoc BodyModelStateCache in TodayScreen and
//  eliminates the 11-model recompute-per-render in InsightsScreen.
//  New insights add one property + one line in update(for:).
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class SessionAnalytics {

    // Cached reports — set by update(for:) and read by screens.
    var volume: [MuscleVolumeStat]
    var development: MuscleDevelopment.State
    var strength: StrengthOutlookBoard
    var progress: [ExerciseProgress]
    var dominance: ExerciseDominanceBoard
    var intensity: IntensityMix
    var intensityWeeks: [IntensityWeek]
    var migration: RepRangeMigrationReport
    var composition: CompositionSplit
    var symmetry: AntagonistBoard
    var consistency: ConsistencyReport
    var load: TrainingLoadReport
    var lastInstances: [String: LastExerciseInstance]

    private var fingerprint: String = ""

    init() {
        let empty: [WorkoutSession] = []
        volume = empty.muscleVolume()
        development = MuscleDevelopment.simulate(from: empty)
        strength = empty.strengthOutlook()
        progress = empty.progressByExercise
        dominance = empty.exerciseDominance()
        intensity = empty.intensityMix()
        intensityWeeks = empty.weeklyIntensity()
        migration = empty.repRangeMigration()
        composition = empty.compoundIsolationSplit()
        symmetry = empty.antagonistBalance()
        consistency = empty.consistency()
        load = empty.trainingLoad()
        lastInstances = empty.lastInstanceByExercise()
    }

    /// Recompute all reports only when the dataset has actually
    /// changed. Archived sessions are immutable history, so count +
    /// latest completion fully identify the input.
    func update(for sessions: [WorkoutSession]) {
        let sig = "\(sessions.count)-\(sessions.first?.completedAt?.timeIntervalSince1970 ?? 0)"
        guard sig != fingerprint else { return }
        fingerprint = sig

        volume = sessions.muscleVolume()
        development = MuscleDevelopment.simulate(from: sessions)
        strength = sessions.strengthOutlook()
        progress = sessions.progressByExercise
        dominance = sessions.exerciseDominance()
        intensity = sessions.intensityMix()
        intensityWeeks = sessions.weeklyIntensity()
        migration = sessions.repRangeMigration()
        composition = sessions.compoundIsolationSplit()
        symmetry = sessions.antagonistBalance()
        consistency = sessions.consistency()
        load = sessions.trainingLoad()
        lastInstances = sessions.lastInstanceByExercise()
    }
}

// MARK: - Environment injection

/// Lets views without direct AppState access (e.g. ExerciseDetailScreen
/// presented from a NavigationLink) share the cached analytics.
private struct SessionAnalyticsKey: EnvironmentKey {
    static let defaultValue: SessionAnalytics? = nil
}

extension EnvironmentValues {
    var sessionAnalytics: SessionAnalytics? {
        get { self[SessionAnalyticsKey.self] }
        set { self[SessionAnalyticsKey.self] = newValue }
    }
}

//
//  SessionAnalyticsReports.swift
//  vivobody
//
//  Immutable core and Insights-tier report payloads derived from one
//  analytics accumulator and safe to cross the worker boundary.
//

import Foundation
import VivoKit

extension SessionAnalytics {
    /// Reports shared by Today, Me, Insights, and exercise-library
    /// surfaces. Every stored value is safe to cross back from the
    /// background worker.
    nonisolated struct CoreReports {
        let volume: [MuscleVolumeStat]
        let groupVolume: [MuscleGroup: Double]
        let development: MuscleDevelopment.State
        let muscleMap: MuscleMapReport
        let strength: StrengthOutlookBoard
        let progress: [ExerciseProgress]
        let load: TrainingLoadReport
        let stamina: SetSeriesStamina
        let workoutLoadBaseline: WorkoutLoadBaseline
        let consistency: ConsistencyReport
        let exerciseHistory: [String: ExerciseHistorySummary]
        let exerciseDetail: ExerciseDetailReports
        let overview: ArchiveOverview

        nonisolated var lastInstances: [String: LastExerciseInstance] {
            exerciseHistory.compactMapValues { $0.lastExerciseInstance }
        }

        nonisolated static func make(
            from common: AnalyticsAccumulator,
            now: Date,
            isCancelled: @Sendable () -> Bool = { false }
        ) -> CoreReports {
            make(
                from: common,
                now: now,
                isCancelled: isCancelled,
                checkpoint: {}
            )
        }

        nonisolated static func make(
            from common: AnalyticsAccumulator,
            now: Date,
            isCancelled: @Sendable () -> Bool,
            checkpoint: @Sendable () throws -> Void
        ) rethrows -> CoreReports {
            let progress = common.progressByExercise(
                isCancelled: isCancelled
            )
            try checkpoint()
            let volume = common.muscleVolume(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let development = MuscleDevelopment.simulate(
                from: common,
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let muscleMap = MuscleMapReport.compute(
                accumulator: common,
                development: development,
                volume: volume,
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let strength = StrengthOutlookBoard.compute(
                progress: progress,
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let load = common.trainingLoad(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let workoutLoadBaseline = WorkoutLoadBaseline.make(
                from: common.sessions
            )
            try checkpoint()
            let consistency = common.consistency(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let history = common.exerciseHistoryByExercise(
                isCancelled: isCancelled
            )
            try checkpoint()
            let stamina = SetSeriesStamina.make(
                series: common.staminaSeries(now: now, isCancelled: isCancelled), now: now
            )
            try checkpoint()
            let exerciseDetail = ExerciseDetailReports.make(
                from: common,
                history: history,
                progress: progress,
                strength: strength,
                weeklyVolume: volume,
                stamina: stamina.byExercise,
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let overview = common.archiveOverview(
                progress: progress,
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let groupVolume = common.allTimeMuscleGroupVolume(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            return CoreReports(
                volume: volume,
                groupVolume: groupVolume,
                development: development,
                muscleMap: muscleMap,
                strength: strength,
                progress: progress,
                load: load,
                stamina: stamina,
                workoutLoadBaseline: workoutLoadBaseline,
                consistency: consistency,
                exerciseHistory: history,
                exerciseDetail: exerciseDetail,
                overview: overview
            )
        }
    }

    /// Reports whose only app consumer is Insights.
    nonisolated struct DeepReports {
        let dominance: ExerciseDominanceBoard
        let intensity: IntensityMix
        let intensityWeeks: [IntensityWeek]
        let migration: RepRangeMigrationReport
        let composition: CompositionSplit
        let movementCoverage: MovementCoverage
        let muscleDirectness: MuscleDirectness
        let symmetry: AntagonistBoard
        let consistency: ConsistencyReport

        nonisolated static func make(
            from common: AnalyticsAccumulator,
            now: Date,
            consistency: ConsistencyReport? = nil
        ) -> DeepReports {
            make(
                from: common,
                now: now,
                consistency: consistency,
                isCancelled: { false },
                checkpoint: {}
            )
        }

        nonisolated static func make(
            from common: AnalyticsAccumulator,
            now: Date,
            consistency: ConsistencyReport?,
            isCancelled: @Sendable () -> Bool,
            checkpoint: @Sendable () throws -> Void
        ) rethrows -> DeepReports {
            let dominance = common.exerciseDominance(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let intensity = common.intensityMix(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let intensityWeeks = common.weeklyIntensity(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let migration = common.repRangeMigration(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let composition = common.compoundIsolationSplit(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let symmetry = common.antagonistBalance(
                now: now,
                isCancelled: isCancelled
            )
            try checkpoint()
            let movementCoverage = common.movementCoverage(now: now, isCancelled: isCancelled)
            try checkpoint()
            let muscleDirectness = common.muscleDirectness(now: now, isCancelled: isCancelled)
            try checkpoint()
            let resolvedConsistency: ConsistencyReport
            if let consistency {
                resolvedConsistency = consistency
            } else {
                resolvedConsistency = common.consistency(
                    now: now,
                    isCancelled: isCancelled
                )
                try checkpoint()
            }
            return DeepReports(
                dominance: dominance,
                intensity: intensity,
                intensityWeeks: intensityWeeks,
                migration: migration,
                composition: composition,
                movementCoverage: movementCoverage,
                muscleDirectness: muscleDirectness,
                symmetry: symmetry,
                consistency: resolvedConsistency
            )
        }
    }

    /// One coherent Insights payload. Core and deep reports are
    /// published together only after both were built from the same
    /// fingerprint and accumulator.
    nonisolated struct InsightsReports {
        let core: CoreReports
        let deep: DeepReports
    }

    /// Widget-only analytics derived beside the core tier from the
    /// same accumulator.
    nonisolated struct WidgetReports {
        let consistency: ConsistencySnapshot
        let signature: SignatureSnapshot
        let strength: StrengthSnapshot
        let load: TrainingLoadReport
    }
}

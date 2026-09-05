//
//  ExerciseDetailReadModel.swift
//  vivobody
//
//  Immutable analytics input for Exercise Detail. A single factory snapshots
//  the catalog item and consumes one coherent published report generation.
//  Focused views receive formatted values and accessibility text without
//  retaining SwiftData objects or rescanning workout relationships.
//

import Foundation

nonisolated struct ExerciseDetailReadModel: Hashable {
    static let plateauThreshold = 5
    static let recentSessionLimit = ExerciseHistorySummary.recentInstanceLimit
    static let cadenceEventLimit = 7
    static let weeklyVolumeRowLimit = 4

    /// Catalog and preference values copied before report construction.
    struct ExerciseDescriptor: Hashable {
        let name: String
        let modality: ExerciseModality
        let trackingMode: TrackingMode
        let loadMode: ExerciseLoadMode
        let bodyweightFraction: Double
        let tracksResistance: Bool
        let measuredOneRepMax: Double?
        /// Canonical pounds, resolved from the current unit's native default.
        let defaultLoggedWeight: Double
        /// Canonical pounds; zero is the existing unknown sentinel.
        let currentBodyweight: Double

        var performanceSemanticKind: PerformanceSemanticKind {
            modality.performanceSemanticKind(
                for: trackingMode,
                loadMode: loadMode
            )
        }

        var supportsPerformanceRecord: Bool {
            performanceSemanticKind.supportsRecord
        }

        var supportsEstimatedOneRepMax: Bool {
            modality.supportsEstimatedOneRepMax(
                for: trackingMode,
                loadMode: loadMode
            )
        }
    }

    enum HistoryState: Hashable {
        case empty
        case single
        case many
    }

    struct MetricText: Hashable {
        let display: String
        let accessibilityLabel: String
    }

    struct BestSet: Hashable {
        let value: String
        let unit: String?
        let detail: String?
        let date: Date?
        let dateText: String?
        let accessibilityLabel: String
    }

    struct Frequency: Hashable {
        let sessionCount: Int
        let sessionCountText: String
        let sessionsAccessibilityLabel: String
        let perWeek: Double?
        let perWeekText: String
        let perWeekAccessibilityLabel: String
        let lastDate: Date
        let lastDateText: String
        let lastDateAccessibilityLabel: String
        let accessibilityLabel: String
    }

    struct EffectiveLoad: Hashable {
        /// Canonical pounds. Nil means the historical bodyweight is unknown.
        let value: Double?
        let valueText: String
        let formulaText: String?
        let explanationText: String
        let accessibilityLabel: String
    }

    struct RecentSession: Hashable {
        let date: Date
        let dateText: String
        let relativeDateText: String
        let metric: MetricText
        let completedSetCount: Int
        let setCountText: String
        let isPersonalRecord: Bool
        let accessibilityLabel: String
    }

    struct Effort: Hashable {
        let averageRIR: Double
        let averageText: String
        let lastSessionSetCount: Int
        let lastSessionText: String
        let lifetimeLoggedSetCount: Int
        let verdict: ProgressionVerdict
        let headline: String?
        let accessibilityLabel: String
    }

    struct LoadEvent: Hashable {
        let date: Date
        /// Canonical pounds.
        let load: Double
    }

    struct Cadence: Hashable {
        let visibleEvents: [LoadEvent]
        let showsRecentSubset: Bool
        let medianGapDays: Int
        let daysSinceLastIncrease: Int
        let isPastUsualRhythm: Bool
        let isEarlyRead: Bool
        let usualPaceText: String
        let currentGapText: String
        let currentDetailText: String
        let evidenceText: String
        let loadRangeText: String
        let accessibilityLabel: String
    }

    struct WeeklyVolumeRow: Hashable {
        let muscle: Muscle
        let role: MuscleRole?
        let contributionSets: Double
        let totalSets: Double
        let landmark: VolumeLandmark
        let zone: VolumeZone?
        let contributionText: String
        let totalText: String
        let accessibilityLabel: String
    }

    struct WeeklyVolume: Hashable {
        let rows: [WeeklyVolumeRow]
        let bandText: String
        let caption: String
    }

    let exercise: ExerciseDescriptor
    /// Clock snapshot shared by standalone chart filtering and placeholders.
    let now: Date
    let historyState: HistoryState
    let sessionCount: Int
    /// Latest immutable history occurrence for the single-point chart fallback.
    let latestHistoryInstance: ExerciseHistoryInstance?
    /// The exact immutable source selected for the standing Best-set display.
    let recordSource: RecordSource?
    let progress: ExerciseProgress?
    let strengthTrendStat: StrengthOutlookStat?
    let strengthTrendReadinessDates: [Date]
    let bestSet: BestSet
    let frequency: Frequency?
    let effectiveLoad: EffectiveLoad?
    /// Canonical pounds. Multi-session progress uses confidence-eligible
    /// samples; one session retains the existing positive-reps Epley fallback.
    let estimatedOneRepMax: Double?
    /// Canonical pounds used to seed the tested-max editor.
    let oneRepMaxSeed: Double
    let plateauStatus: PlateauStatus?
    let recentSessions: [RecentSession]
    let effort: Effort?
    let cadence: Cadence?
    let weeklyVolume: WeeklyVolume?
    let stamina: ExerciseStamina?

    var hasHistory: Bool {
        historyState != .empty
    }

    /// Pure value construction from already-resolved analytics contracts.
    /// `now` and `calendar` are explicit so every relative/cadence branch is
    /// deterministic in focused tests.
    @MainActor
    init(
        exercise: ExerciseDescriptor,
        history: ExerciseHistorySummary?,
        progress: ExerciseProgress?,
        strengthTrendStat: StrengthOutlookStat?,
        effort: ExerciseEffortSummary?,
        volumeContribution: ExerciseVolumeContribution?,
        weeklyVolumeByMuscle: [Muscle: MuscleVolumeStat],
        stamina: ExerciseStamina? = nil,
        unit: WeightUnit,
        now: Date,
        calendar: Calendar,
        plateauThreshold: Int = plateauThreshold
    ) {
        self.exercise = exercise
        self.stamina = stamina
        self.now = now
        self.progress = progress
        latestHistoryInstance = history?.mostRecentInstance
        self.strengthTrendStat = exercise.supportsEstimatedOneRepMax
            ? strengthTrendStat
            : nil
        strengthTrendReadinessDates = exercise.supportsEstimatedOneRepMax
            ? history?.estimatedOneRepMaxDates ?? []
            : []

        let count = history?.sessionCount ?? 0
        sessionCount = count
        historyState = switch count {
        case 0: .empty
        case 1: .single
        default: .many
        }

        let selectedRecordSource = Self.recordSource(
            exercise: exercise,
            history: history,
            progress: progress
        )
        recordSource = selectedRecordSource
        bestSet = Self.bestSet(
            source: selectedRecordSource,
            exercise: exercise,
            unit: unit,
            now: now,
            calendar: calendar
        )
        frequency = Self.frequency(
            history: history,
            progress: progress,
            now: now,
            calendar: calendar
        )
        effectiveLoad = Self.effectiveLoad(
            exercise: exercise,
            history: history,
            progress: progress,
            unit: unit
        )

        let estimate = Self.estimatedOneRepMax(
            exercise: exercise,
            history: history,
            progress: progress
        )
        estimatedOneRepMax = estimate
        oneRepMaxSeed = Self.oneRepMaxSeed(
            exercise: exercise,
            progress: progress,
            estimatedOneRepMax: estimate
        )
        plateauStatus = progress?.plateauStatus(threshold: plateauThreshold)
        recentSessions = Self.recentSessions(
            history: history,
            supportsPerformanceRecord: exercise.supportsPerformanceRecord,
            unit: unit,
            now: now,
            calendar: calendar
        )
        self.effort = Self.effort(
            effort,
            exercise: exercise
        )

        let cadence: ProgressionCadence? = if exercise.performanceSemanticKind.comparesLoad,
                                              let points = progress?.points
        {
            ProgressionCadence.compute(
                points: points,
                now: now,
                calendar: calendar
            )
        } else {
            nil
        }
        self.cadence = Self.cadence(
            cadence,
            unit: unit
        )
        weeklyVolume = Self.weeklyVolume(
            contribution: volumeContribution,
            statsByMuscle: weeklyVolumeByMuscle
        )
    }
}

// MARK: - SwiftData-facing construction boundary

extension ExerciseDetailReadModel {
    /// The only Exercise Detail construction boundary. `SessionAnalytics`
    /// supplies one already-indexed generation, so this performs only direct
    /// key lookups plus bounded formatting and retains only value types.
    @MainActor
    static func make(
        item: ExerciseCatalogItem,
        cached: ExerciseDetailReports = .empty,
        unit: WeightUnit,
        currentBodyweight: Double,
        calendar: Calendar = .current
    ) -> ExerciseDetailReadModel {
        let exercise = ExerciseDescriptor(
            name: item.name,
            modality: item.modality,
            trackingMode: item.trackingMode,
            loadMode: item.loadMode,
            bodyweightFraction: item.bodyweightFraction,
            tracksResistance: item.tracksResistance,
            measuredOneRepMax: item.oneRepMax,
            defaultLoggedWeight: item.defaultWeight(forUnit: unit),
            currentBodyweight: currentBodyweight
        )
        let historyKey = item.historyKey
        let currentRoles = item.muscleInvolvement.roles

        return ExerciseDetailReadModel(
            exercise: exercise,
            history: cached.historyByKey[historyKey],
            progress: cached.progressByKey[historyKey],
            strengthTrendStat: cached.strengthByKey[historyKey],
            effort: exercise.supportsEstimatedOneRepMax
                ? cached.effortByKey[historyKey]
                : nil,
            volumeContribution: ExerciseVolumeContribution.relabel(
                cached.rawVolumeByKey[historyKey],
                currentRoles: currentRoles,
            ),
            weeklyVolumeByMuscle: cached.weeklyVolumeByMuscle,
            stamina: cached.staminaByKey[historyKey],
            unit: unit,
            now: cached.generatedAt,
            calendar: calendar
        )
    }
}

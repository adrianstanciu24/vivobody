//
//  TodayUpNextPresentation.swift
//  vivobody
//
//  Immutable presentation for Today's scheduled or repeat-workout preview. A narrow
//  MainActor adapter snapshots SwiftData templates, the matching archived session,
//  and strength outlook into primitive values; all formatting, preview limits, and
//  accessibility copy are then derived without store, environment, or UserDefaults
//  access.
//

import Foundation

nonisolated struct TodayUpNextPresentation: Equatable {
    nonisolated struct Source: Equatable {
        nonisolated struct Exercise: Equatable {
            nonisolated struct SetPlan: Equatable {
                let reps: Int
                let duration: TimeInterval
                let weight: Double
            }

            let id: UUID
            let name: String
            let groupName: String
            let historyKey: String
            let trackingModeRaw: String
            let durationLabel: String
            let loadModeRaw: String
            let plannedSets: Int
            let plannedReps: Int
            let plannedDuration: TimeInterval
            let plannedWeight: Double
            let sets: [SetPlan]

            var effectiveSetCount: Int {
                sets.isEmpty ? plannedSets : sets.count
            }
        }

        /// Totals of the most recent archived workout that covered this
        /// template's exercises. Receipt semantics stay shared with History.
        nonisolated struct LastSession: Equatable {
            let date: Date
            let totalSets: Int
            let totalReps: Int
            let receipt: WorkoutReceiptMetric
        }

        nonisolated struct NearestPR: Equatable {
            let historyKey: String
            let exerciseName: String
            let currentE1RM: Double
            let bestE1RM: Double
            let isFresh: Bool
        }

        let templateName: String
        let daysUntil: Int
        let otherScheduledCount: Int
        let shouldEaseOff: Bool
        let exercises: [Exercise]
        let nearestPR: NearestPR?
        var lastUsedAt: Date? = nil
        var lastSession: LastSession? = nil
    }

    nonisolated struct ExerciseRow: Equatable, Identifiable {
        let id: UUID
        let name: String
        let groupName: String
        /// Set structure only, such as `3 × 8` or `2 × 0:30 hold`. Loads are
        /// resolved when the workout starts and belong to the template detail.
        let scheme: String

        var accessibilityLabel: String {
            "\(name), \(scheme), \(groupName)"
        }
    }

    nonisolated struct Preview: Equatable {
        let rows: [ExerciseRow]
        let remainingCount: Int
    }

    /// The card's single logged reference. `columns` is empty when no
    /// archived workout covered this template within Today's recent window.
    nonisolated struct LastTime: Equatable {
        nonisolated struct Column: Equatable {
            let value: String
            var unit: String? = nil
            let label: String
            let accessibilityLabel: String
        }

        let title: String
        let columns: [Column]
        let accessibilityLabel: String
    }

    nonisolated struct LoadGuidance: Equatable {
        let text: String
        let accessibilityLabel: String
    }

    let templateName: String
    let scheduleText: String
    let metadata: String
    let durationEstimate: String?
    let muscleGroups: [String]
    var muscleSummary: String {
        muscleGroups.joined(separator: "   ")
    }

    let exerciseRows: [ExerciseRow]
    let lastTime: LastTime
    let prProximityText: String?
    let loadGuidance: LoadGuidance?

    init(
        source: Source,
        unit: WeightUnit,
        defaultRestSeconds: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        templateName = source.templateName
        scheduleText = Self.scheduleText(daysUntil: source.daysUntil)
        durationEstimate = Self.durationEstimate(
            exercises: source.exercises,
            defaultRestSeconds: defaultRestSeconds
        )
        metadata = Self.metadata(
            exerciseCount: source.exercises.count,
            durationEstimate: durationEstimate,
            otherScheduledCount: source.otherScheduledCount
        )
        muscleGroups = Self.muscleGroups(source.exercises)
        exerciseRows = source.exercises.map { exercise in
            ExerciseRow(
                id: exercise.id,
                name: exercise.name,
                groupName: exercise.groupName,
                scheme: Self.scheme(for: exercise)
            )
        }
        lastTime = Self.lastTime(
            session: source.lastSession,
            lastUsedAt: source.lastUsedAt,
            now: now,
            calendar: calendar
        )
        prProximityText = Self.prProximityText(
            source.nearestPR,
            exercises: source.exercises,
            unit: unit
        )
        loadGuidance = source.shouldEaseOff
            ? LoadGuidance(
                text: "High load, keep this session lighter",
                accessibilityLabel: "High training load, keep this session lighter"
            )
            : nil
    }

    /// Up to four rows normally and three at accessibility sizes. When exactly
    /// one exercise would remain, show it instead of a "+1 more" row.
    func preview(accessibilityLayout: Bool) -> Preview {
        let limit = accessibilityLayout ? 3 : 4
        let rows = exerciseRows.count <= limit + 1
            ? exerciseRows
            : Array(exerciseRows.prefix(limit))
        return Preview(
            rows: rows,
            remainingCount: exerciseRows.count - rows.count
        )
    }

    static func scheduleText(daysUntil: Int) -> String {
        switch daysUntil {
        case -1: "Repeat option"
        case 0: "Today"
        case 1: "Tomorrow"
        default: "in \(daysUntil) days"
        }
    }

    private static func durationEstimate(
        exercises: [Source.Exercise],
        defaultRestSeconds: Int
    ) -> String? {
        let sets = exercises.reduce(0) { $0 + $1.effectiveSetCount }
        guard sets > 0 else { return nil }
        let rest = defaultRestSeconds > 0
            ? defaultRestSeconds
            : SettingsDefaults.defaultRestSeconds
        let workSecondsPerSet = 45.0
        let total = Double(sets) * (Double(rest) + workSecondsPerSet)
        let minutes = max(5, Int((total / 60 / 5).rounded()) * 5)
        return "~\(minutes) min"
    }

    private static func metadata(
        exerciseCount: Int,
        durationEstimate: String?,
        otherScheduledCount: Int
    ) -> String {
        var parts = ["\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises")"]
        if let durationEstimate {
            parts.append(durationEstimate)
        }
        let base = parts.joined(separator: "  ·  ")
        return otherScheduledCount > 0
            ? "\(base)  ·  +\(otherScheduledCount) more"
            : base
    }

    private static func muscleGroups(_ exercises: [Source.Exercise]) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for exercise in exercises {
            if counts[exercise.groupName] == nil {
                order.append(exercise.groupName)
            }
            counts[exercise.groupName, default: 0] += exercise.effectiveSetCount
        }
        return order
            .map { groupName in
                let sets = counts[groupName] ?? 0
                return "\(groupName) · \(sets) \(sets == 1 ? "set" : "sets")"
            }
    }

    private static func scheme(for exercise: Source.Exercise) -> String {
        let trackingMode = TrackingMode(rawValue: exercise.trackingModeRaw) ?? .reps
        switch trackingMode {
        case .reps: return repsScheme(for: exercise)
        case .duration: return durationScheme(for: exercise)
        }
    }

    private static func repsScheme(for exercise: Source.Exercise) -> String {
        guard !exercise.sets.isEmpty else {
            return "\(exercise.plannedSets) × \(exercise.plannedReps)"
        }
        let reps = exercise.sets.map(\.reps)
        guard let lower = reps.min(), let upper = reps.max() else {
            return "\(exercise.sets.count) sets"
        }
        return lower == upper
            ? "\(exercise.sets.count) × \(lower)"
            : "\(exercise.sets.count) × \(lower)–\(upper)"
    }

    private static func durationScheme(for exercise: Source.Exercise) -> String {
        let count: Int
        let duration: String
        if exercise.sets.isEmpty {
            count = exercise.plannedSets
            duration = DurationFormatter.string(exercise.plannedDuration)
        } else {
            count = exercise.sets.count
            let durations = exercise.sets.map(\.duration)
            guard let lower = durations.min(), let upper = durations.max() else {
                return "\(count) sets"
            }
            duration = lower == upper
                ? DurationFormatter.string(lower)
                : "\(DurationFormatter.string(lower))–\(DurationFormatter.string(upper))"
        }
        return "\(count) × \(duration) \(exercise.durationLabel)"
    }

    private static func lastTime(
        session: Source.LastSession?,
        lastUsedAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> LastTime {
        if let session {
            let day = relativeDayText(session.date, now: now, calendar: calendar)
            var columns = [LastTime.Column(
                value: "\(session.totalSets)",
                label: "Sets",
                accessibilityLabel: "\(session.totalSets) \(session.totalSets == 1 ? "set" : "sets")"
            )]
            if session.totalReps > 0 {
                columns.append(LastTime.Column(
                    value: "\(session.totalReps)",
                    label: "Reps",
                    accessibilityLabel: "\(session.totalReps) \(session.totalReps == 1 ? "rep" : "reps")"
                ))
            }
            let receipt = session.receipt
            switch receipt.kind {
            case .volume(.complete):
                columns.append(LastTime.Column(
                    value: receipt.value,
                    unit: receipt.unit,
                    label: receipt.label,
                    accessibilityLabel: receipt.accessibilityLabel
                ))
            case .volume(.partial):
                columns.append(LastTime.Column(
                    value: receipt.value + (receipt.qualifier ?? ""),
                    unit: receipt.unit,
                    label: "Known volume",
                    accessibilityLabel: receipt.accessibilityLabel
                ))
            case .timedWork:
                columns.append(LastTime.Column(
                    value: receipt.value,
                    label: receipt.label,
                    accessibilityLabel: receipt.accessibilityLabel
                ))
            case .volume(.unavailable), .reps:
                break
            }
            return LastTime(
                title: "Last time  ·  \(day)",
                columns: columns,
                accessibilityLabel: (["Last time", day] + columns.map(\.accessibilityLabel))
                    .joined(separator: ", ")
            )
        }
        if let lastUsedAt {
            let day = relativeDayText(lastUsedAt, now: now, calendar: calendar)
            return LastTime(
                title: "Last done  ·  \(day)",
                columns: [],
                accessibilityLabel: "Last done, \(day)"
            )
        }
        return LastTime(
            title: "First time with this workout",
            columns: [],
            accessibilityLabel: "First time with this workout"
        )
    }

    /// Today, Yesterday, a small day count, then a month-and-day date. The
    /// year appears only once the reference leaves the current year.
    static func relativeDayText(_ date: Date, now: Date, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2 ... 6: return "\(days) days ago"
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            let format: Date.FormatStyle = sameYear
                ? .dateTime.month(.abbreviated).day()
                : .dateTime.month(.abbreviated).day().year()
            return date.formatted(format)
        }
    }

    private static func prProximityText(
        _ nearestPR: Source.NearestPR?,
        exercises: [Source.Exercise],
        unit: WeightUnit
    ) -> String? {
        guard let nearestPR, !nearestPR.isFresh else { return nil }
        let gap = nearestPR.bestE1RM - nearestPR.currentE1RM
        guard gap >= 1 else { return nil }
        guard exercises.contains(where: { $0.historyKey == nearestPR.historyKey }) else {
            return nil
        }
        let value = WeightFormatter.string(gap, unit: unit, includeUnit: false)
        return "\(value) \(unit.symbol) from \(article(for: nearestPR.exerciseName)) \(nearestPR.exerciseName) PR"
    }

    static func article(for name: String) -> String {
        guard let first = name.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}

extension TodayUpNextPresentation.Source {
    @MainActor
    init(
        template: WorkoutTemplate,
        daysUntil: Int,
        otherScheduledCount: Int,
        shouldEaseOff: Bool,
        outlook: StrengthOutlookBoard,
        lastSession: WorkoutSession? = nil,
        unit: WeightUnit = .lb
    ) {
        let exercises = template.orderedExercises.map { exercise in
            Exercise(
                id: exercise.id,
                name: exercise.name,
                groupName: exercise.group.displayName,
                historyKey: exercise.historyKey,
                trackingModeRaw: exercise.trackingMode.rawValue,
                durationLabel: exercise.modality.durationLabelLowercased,
                loadModeRaw: exercise.loadMode.rawValue,
                plannedSets: exercise.plannedSets,
                plannedReps: exercise.plannedReps,
                plannedDuration: exercise.plannedDuration,
                plannedWeight: exercise.trackedWeight(exercise.plannedWeight),
                sets: exercise.orderedSets.map { set in
                    Exercise.SetPlan(
                        reps: set.reps,
                        duration: set.duration,
                        weight: exercise.trackedWeight(set.weight)
                    )
                }
            )
        }
        let nearestPR = outlook.nearestPR.map { stat in
            NearestPR(
                historyKey: stat.historyKey,
                exerciseName: stat.exercise,
                currentE1RM: stat.currentE1RM,
                bestE1RM: stat.bestE1RM,
                isFresh: stat.isFreshPR
            )
        }
        self.init(
            templateName: template.name,
            daysUntil: daysUntil,
            otherScheduledCount: otherScheduledCount,
            shouldEaseOff: shouldEaseOff,
            exercises: exercises,
            nearestPR: nearestPR,
            lastUsedAt: template.lastUsedAt,
            lastSession: lastSession.map { session in
                LastSession(
                    date: session.completedAt ?? session.startedAt,
                    totalSets: session.totalSets,
                    totalReps: session.totalReps,
                    receipt: session.primaryReceiptMetric(unit: unit, volumeDisplayStyle: .full)
                )
            }
        )
    }
}

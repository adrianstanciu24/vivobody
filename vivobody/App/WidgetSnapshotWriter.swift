//
//  WidgetSnapshotWriter.swift
//  vivobody
//
//  App-side bridge from SwiftData to WidgetKit. Widgets never open the
//  model store; they read small Codable snapshots written into the App
//  Group whenever workout, schedule, preference, or foreground state
//  changes.
//

import VivoKit
import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetSnapshotWriter {
    /// Coalesces rapid successive `writeAll` calls (template edits,
    /// body-weight saves, scene-phase changes) into a single deferred
    /// update so the main thread isn't blocked synchronously on every
    /// trigger. The 300 ms window is imperceptible to the user but
    /// prevents stacking heavy fetches + analytics + 4 widget reloads.
    private static var pendingWriteAllTask: Task<Void, Never>?

    /// Same coalescing for `writeActiveWorkout`, which fires on every
    /// set completion and rest-state change. Shorter window (200 ms)
    /// since the active-workout snapshot is lighter and more
    /// time-sensitive than the full analytics refresh.
    private static var pendingWriteActiveTask: Task<Void, Never>?

    static func writeAll(in context: ModelContext, reload: Bool = true) {
        pendingWriteAllTask?.cancel()
        pendingWriteAllTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            writeAllNow(in: context, reload: reload)
        }
    }

    static func writeActiveWorkout(in context: ModelContext, reload: Bool = true) {
        pendingWriteActiveTask?.cancel()
        pendingWriteActiveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let unit = WeightUnit.current
            mirrorPreferences(unit: unit)
            write(activeWorkoutSnapshot(session: fetchActiveSession(in: context), unit: unit), key: WidgetShared.activeWorkoutSnapshotKey)
            guard reload else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.activeWorkoutKind)
        }
    }

    static func reloadUpNext() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.upNextKind)
    }

    private static func writeAllNow(in context: ModelContext, reload: Bool) {
        let templates = fetchTemplates(in: context)
        let completed = fetchCompletedSessions(in: context)
        let active = fetchActiveSession(in: context)
        let bodyweight = fetchCurrentBodyweight(in: context)
        let unit = WeightUnit.current

        mirrorPreferences(unit: unit)
        write(
            upNextSnapshot(
                templates: templates,
                sessions: completed,
                unit: unit,
                bodyweight: bodyweight
            ),
            key: WidgetShared.upNextSnapshotKey
        )
        write(consistencySnapshot(sessions: completed), key: WidgetShared.consistencySnapshotKey)
        write(signatureSnapshot(sessions: completed), key: WidgetShared.signatureSnapshotKey)
        write(strengthSnapshot(sessions: completed), key: WidgetShared.strengthSnapshotKey)
        write(activeWorkoutSnapshot(session: active, unit: unit), key: WidgetShared.activeWorkoutSnapshotKey)
        // Publish the template list (id + name) so the Siri App Intent
        // entity query can enumerate templates from the system process
        // without opening the app's SwiftData store.
        write(
            templates.map { TemplateEntitySnapshot(id: $0.id.uuidString, name: $0.name) },
            key: WidgetShared.templatesSnapshotKey
        )

        guard reload else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.upNextKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.consistencyKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.signatureKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.strengthKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.activeWorkoutKind)
    }

    // MARK: - Fetching

    private static func fetchTemplates(in context: ModelContext) -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchCompletedSessions(in context: ModelContext) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchActiveSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func fetchCurrentBodyweight(in context: ModelContext) -> Double? {
        var descriptor = FetchDescriptor<BodyWeightEntry>(
            predicate: #Predicate { $0.weight > 0 },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.weight
    }

    // MARK: - Snapshots

    private static func upNextSnapshot(
        templates: [WorkoutTemplate],
        sessions: [WorkoutSession],
        unit: WeightUnit,
        bodyweight: Double?
    ) -> UpNextSnapshot {
        let upNext = UpNext.compute(templates: templates, sessions: sessions)
        let readiness = sessions.readiness()?.phrase

        switch upNext.kind {
        case let .scheduled(template, _, easeOff):
            return UpNextSnapshot(
                kind: .scheduled,
                templateName: template.name,
                exerciseCount: template.orderedExercises.count,
                totalSets: template.totalPlannedSets,
                totalVolume: plannedVolume(template, bodyweight: bodyweight),
                easeOff: easeOff,
                restReason: nil,
                nextTemplateName: nil,
                daysUntil: 0,
                readinessPhrase: readiness,
                exercises: template.orderedExercises.map { exerciseSnapshot($0, unit: unit) }
            )

        case let .rest(reason, next, daysUntil, _):
            return UpNextSnapshot(
                kind: .rest,
                templateName: nil,
                exerciseCount: next?.orderedExercises.count ?? 0,
                totalSets: next?.totalPlannedSets ?? 0,
                totalVolume: next.map {
                    plannedVolume($0, bodyweight: bodyweight)
                } ?? 0,
                easeOff: false,
                restReason: reason == .offDay ? .offDay : .doneToday,
                nextTemplateName: next?.name,
                daysUntil: daysUntil,
                readinessPhrase: readiness,
                exercises: next?.orderedExercises.map { exerciseSnapshot($0, unit: unit) } ?? []
            )

        case .unscheduled:
            return UpNextSnapshot.empty
        }
    }

    private static func consistencySnapshot(sessions: [WorkoutSession]) -> ConsistencySnapshot {
        let report = sessions.consistency()
        let weeks = report.weeks.map { column in
            column.map {
                ConsistencyDaySnapshot(
                    date: $0.date,
                    level: $0.level,
                    isInRange: $0.isInRange,
                    isToday: $0.isToday
                )
            }
        }
        let weeklyVolume = report.weeks.map { column in
            column.filter(\.isInRange).reduce(0) { $0 + $1.sets }
        }
        return ConsistencySnapshot(
            weeks: weeks,
            sessionsPerWeek: report.sessionsPerWeek,
            weekStreak: report.weekStreak,
            averageRIR: report.averageRIR,
            daysTrained: report.daysTrainedInWindow,
            weeklyVolume: weeklyVolume
        )
    }

    private static func signatureSnapshot(sessions: [WorkoutSession]) -> SignatureSnapshot {
        let report = sessions.consistency()
        let signature = sessions.trainingSignature()
        guard signature.hasSignature else { return SignatureSnapshot.empty }
        return SignatureSnapshot(
            petals: signature.petals.map {
                SignaturePetalSnapshot(
                    group: $0.group.displayName,
                    volumeShare: $0.volumeShare,
                    development: $0.development
                )
            },
            intensity: signature.intensity,
            cadence: signature.cadence,
            balance: signature.balance,
            dominantGroup: signature.dominantGroup?.displayName,
            hasSignature: signature.hasSignature,
            verdictLine: signatureVerdict(signature),
            weekStreak: report.weekStreak
        )
    }

    private static func strengthSnapshot(sessions: [WorkoutSession]) -> StrengthSnapshot {
        let board = sessions.strengthOutlook()
        guard let lead = board.stats.first else { return .empty }

        // Same running-max PR flagging the Insights strength chart
        // uses, kept in canonical lb; the widget converts at display.
        let series = sessions.progressByExercise
            .first { $0.id == lead.historyKey }
        var runningMax = -Double.infinity
        var points: [StrengthPointSnapshot] = []
        for point in series?.points ?? [] where point.estimated1RM > 0 {
            let isPR = point.estimated1RM > runningMax
            if isPR { runningMax = point.estimated1RM }
            points.append(StrengthPointSnapshot(date: point.date, e1RM: point.estimated1RM, isPR: isPR))
        }

        return StrengthSnapshot(
            exercise: lead.exercise,
            points: Array(points.suffix(StrengthSnapshot.maxPoints)),
            currentE1RM: lead.currentE1RM,
            bestE1RM: lead.bestE1RM,
            trendLabel: strengthTrendLabel(lead),
            climbingCount: board.climbingCount,
            stalledCount: board.plateauedCount,
            slippingCount: board.slippingCount,
            hasData: !points.isEmpty
        )
    }

    /// Mirrors the Insights strength section's trend chip wording.
    private static func strengthTrendLabel(_ stat: StrengthOutlookStat) -> String {
        switch stat.trend {
        case .climbing:
            if stat.isFreshPR { return "PR" }
            if let days = stat.daysToPR {
                return days <= 21 ? "~\(days)d" : "~\(Int((Double(days) / 7).rounded()))w"
            }
            return "up"
        case .plateaued:
            if let w = stat.weeksSinceBest, w > 0 { return "\(w)w flat" }
            return "flat"
        case .slipping:
            return "down"
        }
    }

    private static func activeWorkoutSnapshot(session: WorkoutSession?, unit: WeightUnit) -> ActiveWorkoutSnapshot {
        guard let session else { return .empty }
        let exercises = session.orderedExercises
        let safeIndex = min(max(session.activeExerciseIndex, 0), max(exercises.count - 1, 0))
        let exercise = exercises.indices.contains(safeIndex) ? exercises[safeIndex] : exercises.first
        let activeSetIndex = exercise.flatMap { session.activeSetIndex(for: $0) } ?? 0
        let activeSet = exercise.flatMap { session.activeSet(for: $0) }

        return ActiveWorkoutSnapshot(
            isActive: true,
            exerciseName: exercise?.name,
            exerciseIndex: safeIndex,
            totalExercises: exercises.count,
            setNumber: activeSetIndex + 1,
            plannedSets: exercise?.orderedSets.count ?? 0,
            setSpec: activeSet.map { setSpec(for: $0, exercise: exercise, unit: unit) },
            isResting: session.isResting,
            restEndsAt: session.restEndsAt,
            restDuration: session.restDuration,
            totalVolume: session.totalVolume,
            totalSetsCompleted: session.totalSets
        )
    }

    // MARK: - Formatting

    private static func exerciseSnapshot(_ exercise: TemplateExercise, unit: WeightUnit) -> UpNextExerciseSnapshot {
        UpNextExerciseSnapshot(name: exercise.name, setSpec: templateSpec(exercise, unit: unit))
    }

    private static func templateSpec(_ exercise: TemplateExercise, unit: WeightUnit) -> String {
        if let first = exercise.orderedSets.first {
            let count = exercise.orderedSets.count
            switch exercise.trackingMode {
            case .reps:
                let base = "\(count) x \(first.reps)"
                guard let load = exercise.loadMode.summaryLoadLabel(first.weight, unit: unit) else {
                    return base
                }
                return "\(base) @ \(load)"
            case .duration:
                let duration = DurationFormatter.compact(first.duration)
                let base = "\(count) x \(duration) \(exercise.modality.durationLabelLowercased)"
                guard let load = exercise.loadMode.summaryLoadLabel(first.weight, unit: unit) else {
                    return base
                }
                return "\(base) @ \(load)"
            }
        }

        switch exercise.trackingMode {
        case .reps:
            let base = "\(exercise.plannedSets) x \(exercise.plannedReps)"
            guard let load = exercise.loadMode.summaryLoadLabel(
                exercise.plannedWeight,
                unit: unit
            ) else { return base }
            return "\(base) @ \(load)"
        case .duration:
            let duration = DurationFormatter.compact(exercise.plannedDuration)
            let base = "\(exercise.plannedSets) x \(duration) \(exercise.modality.durationLabelLowercased)"
            guard let load = exercise.loadMode.summaryLoadLabel(
                exercise.plannedWeight,
                unit: unit
            ) else { return base }
            return "\(base) @ \(load)"
        }
    }

    private static func plannedVolume(
        _ template: WorkoutTemplate,
        bodyweight: Double?
    ) -> Double {
        template.exercises.reduce(0) { total, exercise in
            guard exercise.modality.supportsComparableTonnage(
                for: exercise.trackingMode,
                loadMode: exercise.loadMode
            ) else { return total }
            if !exercise.orderedSets.isEmpty {
                return total + exercise.orderedSets.reduce(0) { subtotal, set in
                    guard let load = plannedLoad(
                        for: exercise,
                        loggedWeight: set.weight,
                        bodyweight: bodyweight
                    ) else {
                        return subtotal
                    }
                    return subtotal + load * Double(set.reps)
                }
            }
            guard let load = plannedLoad(
                for: exercise,
                loggedWeight: exercise.plannedWeight,
                bodyweight: bodyweight
            ) else { return total }
            return total + Double(exercise.plannedSets * exercise.plannedReps) * load
        }
    }

    /// Bodyweight-derived tonnage is unavailable until the user has
    /// supplied body weight. External load remains independently known.
    private static func plannedLoad(
        for exercise: TemplateExercise,
        loggedWeight: Double,
        bodyweight: Double?
    ) -> Double? {
        switch exercise.loadMode {
        case .external:
            return exercise.loadProfile.effectiveLoad(
                loggedWeight: loggedWeight,
                bodyweight: 0
            )
        case .bodyweightAdded, .assistanceSubtracted:
            guard let bodyweight else { return nil }
            return exercise.loadProfile.effectiveLoad(
                loggedWeight: loggedWeight,
                bodyweight: bodyweight
            )
        case .nonComparable:
            return nil
        }
    }

    private static func setSpec(for set: WorkoutSet, exercise: Exercise?, unit: WeightUnit) -> String {
        guard let exercise else { return "" }
        return SetSpecFormatter.format(
            weight: set.weight,
            reps: set.reps,
            duration: set.duration,
            trackingMode: exercise.trackingMode,
            loadMode: exercise.loadMode,
            unit: unit
        )
    }

    private static func signatureVerdict(_ signature: TrainingSignature) -> String {
        let focus = signature.dominantGroup.map { "\($0.displayName)-led" } ?? "Balanced across every region"
        let effort: String
        if signature.intensity >= 0.6 {
            effort = "Trained close to failure"
        } else if signature.intensity >= 0.4 {
            effort = "Pushed at a steady clip"
        } else {
            effort = "Plenty left in the tank"
        }
        return "\(focus). \(effort), \(InsightsFormat.perWeekLabel(signature.cadence))x a week."
    }

    // MARK: - Persistence

    private static func write<T: Codable>(_ snapshot: T, key: String) {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            let data = WidgetSnapshotCodec.encode(snapshot)
        else { return }
        defaults.set(data, forKey: key)
    }

    private static func mirrorPreferences(unit: WeightUnit) {
        let defaults = UserDefaults(suiteName: WidgetShared.appGroup)
        defaults?.set(unit.rawValue, forKey: WidgetShared.weightUnitKey)
        // Keep the widget-side Pro flag in step with the app-side
        // entitlement cache on every snapshot write. ProStore writes
        // the same key on entitlement changes; this covers writes
        // that happen before its async resolution lands.
        defaults?.set(
            UserDefaults.standard.bool(forKey: SettingsKey.proUnlockedCache),
            forKey: WidgetShared.proUnlockedKey
        )
    }
}

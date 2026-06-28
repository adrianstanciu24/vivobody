//
//  WidgetSnapshotWriter.swift
//  vivobody
//
//  App-side bridge from SwiftData to WidgetKit. Widgets never open the
//  model store; they read small Codable snapshots written into the App
//  Group whenever workout, schedule, preference, or foreground state
//  changes.
//

import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetSnapshotWriter {
    static func writeAll(in context: ModelContext, reload: Bool = true) {
        let templates = fetchTemplates(in: context)
        let completed = fetchCompletedSessions(in: context)
        let active = fetchActiveSession(in: context)
        let unit = WeightUnit.current

        mirrorPreferences(unit: unit)
        write(upNextSnapshot(templates: templates, sessions: completed, unit: unit), key: WidgetShared.upNextSnapshotKey)
        write(consistencySnapshot(sessions: completed), key: WidgetShared.consistencySnapshotKey)
        write(signatureSnapshot(sessions: completed), key: WidgetShared.signatureSnapshotKey)
        write(activeWorkoutSnapshot(session: active, unit: unit), key: WidgetShared.activeWorkoutSnapshotKey)

        guard reload else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.upNextKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.consistencyKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.signatureKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.activeWorkoutKind)
    }

    static func writeActiveWorkout(in context: ModelContext, reload: Bool = true) {
        let unit = WeightUnit.current
        mirrorPreferences(unit: unit)
        write(activeWorkoutSnapshot(session: fetchActiveSession(in: context), unit: unit), key: WidgetShared.activeWorkoutSnapshotKey)
        guard reload else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.activeWorkoutKind)
    }

    static func reloadUpNext() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.upNextKind)
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

    // MARK: - Snapshots

    private static func upNextSnapshot(
        templates: [WorkoutTemplate],
        sessions: [WorkoutSession],
        unit: WeightUnit
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
                totalVolume: plannedVolume(template, unit: unit),
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
                totalVolume: next.map { plannedVolume($0, unit: unit) } ?? 0,
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
                return "\(count) x \(first.reps) @ \(WeightFormatter.string(first.weight, unit: unit))"
            case .duration:
                let duration = DurationFormatter.compact(first.duration)
                guard first.weight > 0 else { return "\(count) x \(duration)" }
                return "\(count) x \(duration) @ \(WeightFormatter.string(first.weight, unit: unit))"
            }
        }

        switch exercise.trackingMode {
        case .reps:
            return "\(exercise.plannedSets) x \(exercise.plannedReps) @ \(WeightFormatter.string(exercise.plannedWeight, unit: unit))"
        case .duration:
            let duration = DurationFormatter.compact(exercise.plannedDuration)
            guard exercise.plannedWeight > 0 else { return "\(exercise.plannedSets) x \(duration)" }
            return "\(exercise.plannedSets) x \(duration) @ \(WeightFormatter.string(exercise.plannedWeight, unit: unit))"
        }
    }

    private static func plannedVolume(_ template: WorkoutTemplate, unit: WeightUnit) -> Double {
        template.exercises.reduce(0) { total, exercise in
            guard exercise.trackingMode == .reps else { return total }
            if !exercise.orderedSets.isEmpty {
                return total + exercise.orderedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
            }
            return total + Double(exercise.plannedSets * exercise.plannedReps) * exercise.plannedWeight
        }
    }

    private static func setSpec(for set: WorkoutSet, exercise: Exercise?, unit: WeightUnit) -> String {
        guard let exercise else { return "" }
        switch exercise.trackingMode {
        case .reps:
            return "\(WeightFormatter.string(set.weight, unit: unit, includeUnit: false)) x \(set.reps)"
        case .duration:
            let duration = DurationFormatter.compact(set.duration)
            guard set.weight > 0 else { return duration }
            return "\(WeightFormatter.string(set.weight, unit: unit, includeUnit: false)) x \(duration)"
        }
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

    private static func write<T: Encodable>(_ snapshot: T, key: String) {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: key)
    }

    private static func mirrorPreferences(unit: WeightUnit) {
        UserDefaults(suiteName: WidgetShared.appGroup)?
            .set(unit.rawValue, forKey: WidgetShared.weightUnitKey)
    }
}

//
//  WidgetSnapshotWriter.swift
//  vivobody
//
//  App-side bridge from SwiftData to WidgetKit. Widgets never open the
//  model store; they read small Codable snapshots written into the App
//  Group whenever workout, schedule, or preference state changes.
//  Full snapshot publishes carry a persisted input fingerprint, so a
//  foreground transition only rebuilds when data, day, unit, Pro
//  state, or snapshot schema is stale. Archive analytics are resolved
//  through SessionAnalytics' actor-backed pipeline.
//

import Foundation
import SwiftData
import VivoKit
import WidgetKit

@MainActor
enum WidgetSnapshotWriter {
    /// The app's central analytics coordinator. AppRoot wires it once
    /// before any production snapshot request; keeping a weak reference
    /// avoids giving this process-wide bridge ownership of AppState.
    private weak static var analytics: SessionAnalytics?

    /// Coalesces rapid successive `writeAll` calls (template edits,
    /// body-weight saves, archive changes) into a single deferred
    /// update so the main thread isn't blocked synchronously on every
    /// trigger. The 300 ms window is imperceptible to the user but
    /// prevents stacking heavy fetches + analytics + 4 widget reloads.
    private static var pendingWriteAllTask: Task<Void, Never>?

    /// Same coalescing for `writeActiveWorkout`, which fires on every
    /// set completion and rest-state change. Shorter window (200 ms)
    /// since the active-workout snapshot is lighter and more
    /// time-sensitive than the full analytics refresh.
    private static var pendingWriteActiveTask: Task<Void, Never>?

    static func configure(analytics: SessionAnalytics) {
        self.analytics = analytics
    }

    /// Mark full-widget inputs changed after their durable save, then
    /// coalesce a publish for that exact revision.
    static func writeAll(in context: ModelContext, reload: Bool = true) {
        let revision = advanceDatasetRevision()
        scheduleWriteAll(
            in: context,
            revision: revision,
            reload: reload
        )
    }

    /// Foreground/startup path. Full analytics are skipped when the
    /// last successful publish still matches all inputs. The active
    /// workout remains a lightweight independent refresh because a
    /// suspended debounce may not have reached the App Group.
    static func writeAllIfStale(
        in context: ModelContext,
        reload: Bool = true,
        now: Date = Date()
    ) {
        let revision = datasetRevision
        let fingerprint = snapshotFingerprint(
            revision: revision,
            now: now
        )
        guard lastSnapshotFingerprint != fingerprint else {
            writeActiveWorkout(in: context, reload: reload)
            return
        }
        scheduleWriteAll(
            in: context,
            revision: revision,
            reload: reload,
            now: now
        )
    }

    private static func scheduleWriteAll(
        in context: ModelContext,
        revision: Int,
        reload: Bool,
        now: Date = Date()
    ) {
        pendingWriteAllTask?.cancel()
        pendingWriteAllTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await writeAllNow(
                in: context,
                revision: revision,
                reload: reload,
                now: now
            )
        }
    }

    static func writeActiveWorkout(in context: ModelContext, reload: Bool = true) {
        pendingWriteActiveTask?.cancel()
        pendingWriteActiveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let unit = WeightUnit.current
            mirrorPreferences(unit: unit)
            let didWrite = write(
                activeWorkoutSnapshot(
                    session: fetchActiveSession(in: context),
                    unit: unit
                ),
                key: WidgetShared.activeWorkoutSnapshotKey
            )
            AppDiagnostics.snapshotWrite(
                kind: "active_workout",
                outcome: didWrite ? "success" : "failure"
            )
            guard reload else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.activeWorkoutKind)
        }
    }

    static func reloadUpNext() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.upNextKind)
    }

    private static func writeAllNow(
        in context: ModelContext,
        revision: Int,
        reload: Bool,
        now: Date
    ) async {
        let templates = fetchTemplates(in: context)
        let completed = fetchCompletedSessions(in: context)
        let active = fetchActiveSession(in: context)
        let bodyweight = fetchCurrentBodyweight(in: context)
        let unit = WeightUnit.current
        guard
            let analytics,
            let reports = await analytics.resolvedWidgetReports(
                for: completed,
                now: now
            ),
            !Task.isCancelled
        else { return }

        mirrorPreferences(unit: unit)
        let snapshots: [(key: String, data: Data?)] = [
            (
                WidgetShared.upNextSnapshotKey,
                encode(
                    upNextSnapshot(
                        templates: templates,
                        sessions: completed,
                        unit: unit,
                        bodyweight: bodyweight,
                        load: reports.load,
                        now: now
                    )
                )
            ),
            (WidgetShared.consistencySnapshotKey, encode(reports.consistency)),
            (WidgetShared.signatureSnapshotKey, encode(reports.signature)),
            (WidgetShared.strengthSnapshotKey, encode(reports.strength)),
            (
                WidgetShared.activeWorkoutSnapshotKey,
                encode(activeWorkoutSnapshot(session: active, unit: unit))
            ),
            (
                WidgetShared.templatesSnapshotKey,
                encode(
                    templates.map {
                        TemplateEntitySnapshot(
                            id: $0.id.uuidString,
                            name: $0.name
                        )
                    }
                )
            ),
        ]

        guard publish(snapshots) else {
            AppDiagnostics.snapshotWrite(kind: "all", outcome: "failure")
            return
        }
        lastSnapshotFingerprint = snapshotFingerprint(
            revision: revision,
            now: now
        )
        AppDiagnostics.snapshotWrite(kind: "all", outcome: "success")

        guard reload else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.upNextKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.consistencyKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.signatureKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.strengthKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.activeWorkoutKind)
    }

    // MARK: - Revision

    private static var datasetRevision: Int {
        UserDefaults.standard.integer(
            forKey: SettingsKey.widgetDatasetRevision
        )
    }

    private static var lastSnapshotFingerprint: String? {
        get {
            UserDefaults.standard.string(
                forKey: SettingsKey.widgetSnapshotFingerprint
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: SettingsKey.widgetSnapshotFingerprint
            )
        }
    }

    private static func advanceDatasetRevision() -> Int {
        let revision = datasetRevision &+ 1
        UserDefaults.standard.set(
            revision,
            forKey: SettingsKey.widgetDatasetRevision
        )
        return revision
    }

    private static func snapshotFingerprint(
        revision: Int,
        now: Date
    ) -> String {
        let day = Calendar.current.startOfDay(for: now)
            .timeIntervalSinceReferenceDate
        let proUnlocked = UserDefaults.standard.bool(
            forKey: SettingsKey.proUnlockedCache
        )
        return [
            String(revision),
            String(day),
            WeightUnit.current.rawValue,
            proUnlocked ? "1" : "0",
            String(WidgetSnapshotVersion.current),
        ].joined(separator: "|")
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
        bodyweight: Double?,
        load: TrainingLoadReport,
        now: Date
    ) -> UpNextSnapshot {
        let upNext = UpNext.compute(
            templates: templates,
            sessions: sessions,
            load: load,
            now: now
        )
        let readiness = sessions.readiness(load: load, now: now)?.phrase

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

    private static func activeWorkoutSnapshot(session: WorkoutSession?, unit: WeightUnit) -> ActiveWorkoutSnapshot {
        guard let session else { return .empty }
        let exercises = session.orderedExercises
        let safeIndex = min(max(session.activeExerciseIndex, 0), max(exercises.count - 1, 0))
        let exercise = exercises.indices.contains(safeIndex) ? exercises[safeIndex] : exercises.first
        let sets = exercise?.orderedSets ?? []
        let activeSetIndex = exercise.flatMap { session.activeSetIndex(for: $0) }
        // A fully logged exercise holds on its final set; falling back to
        // index 0 would fabricate a phantom "Set 1" on completed work.
        let activeSet = activeSetIndex.map { sets[$0] } ?? sets.last

        return ActiveWorkoutSnapshot(
            isActive: true,
            exerciseName: exercise?.name,
            exerciseIndex: safeIndex,
            totalExercises: exercises.count,
            setNumber: (activeSetIndex ?? max(sets.count - 1, 0)) + 1,
            plannedSets: sets.count,
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

    // MARK: - Persistence

    private static func write(_ snapshot: some Codable, key: String) -> Bool {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            let data = WidgetSnapshotCodec.encode(snapshot)
        else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    private static func encode(_ snapshot: some Codable) -> Data? {
        WidgetSnapshotCodec.encode(snapshot)
    }

    /// Encode every payload before mutating the App Group. This keeps
    /// the stored fingerprint honest: it advances only after a complete
    /// snapshot set was available and published.
    private static func publish(
        _ snapshots: [(key: String, data: Data?)]
    ) -> Bool {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            snapshots.allSatisfy({ $0.data != nil })
        else { return false }
        for snapshot in snapshots {
            guard let data = snapshot.data else { return false }
            defaults.set(data, forKey: snapshot.key)
        }
        return true
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

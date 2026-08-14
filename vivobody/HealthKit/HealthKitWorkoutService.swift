//
//  HealthKitWorkoutService.swift
//  vivobody
//
//  The single HealthKit boundary (Tier A). Every `import HealthKit`
//  in the app lives here. On archive, the app calls `saveWorkout`;
//  the service writes one HKWorkout (type, start/end, duration) so
//  the session appears in the Health app's workout history.
//
//  It deliberately writes NO calorie sample. An iPhone-only app
//  cannot reliably move the Activity rings — those are computed by
//  the Apple Watch (or the phone's own motion engine), not summed
//  from third-party energy writes — so an estimated number would
//  either do nothing on a Watch-less iPhone or double-count a Watch's
//  real data. We record the honest fact that the workout happened and
//  leave calories to a real sensor (the Watch, via a future Tier B).
//
//  Opt-in, write-only, idempotent, and silent on failure — the
//  SwiftData archive is always the source of truth. Keeping the
//  HealthKit dependency isolated here means a future live session
//  (Tier B) or a Watch target is additive, not a rewrite.
//

import Foundation
import HealthKit
import SwiftData

@MainActor
enum HealthKitWorkoutService {
    private static let store = HKHealthStore()

    /// Sample types this app writes. Tier A shares only the workout
    /// record — no energy, no read types — so no read-usage
    /// description is required.
    private static var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    /// Whether HealthKit exists on this device. False in the
    /// Simulator and on hardware without a Health database.
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether the system would actually present the authorization
    /// prompt on the next request. HealthKit only shows the sheet
    /// once; after that the status is determined and re-requesting
    /// is a silent no-op. Used to gate a priming explainer before
    /// the first prompt.
    static var shouldPrime: Bool {
        guard isAvailable else { return false }
        return store.authorizationStatus(for: HKObjectType.workoutType()) == .notDetermined
    }

    /// Whether the user opted in. Read straight from UserDefaults so
    /// non-view code can gate without @AppStorage (mirrors Haptics).
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.healthKitEnabled) as? Bool
            ?? SettingsDefaults.healthKitEnabled
    }

    /// Whether we are allowed to write workouts right now.
    private static var canWrite: Bool {
        store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// Request write authorization for the Tier A types. Returns
    /// whether workout sharing ended up authorized. Drives the
    /// Settings toggle: revert it to off when this is false.
    static func requestAuthorization() async -> Bool {
        guard isAvailable else {
            AppDiagnostics.healthKitOutcome(
                event: "authorization",
                outcome: "unavailable"
            )
            return false
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: [])
        } catch {
            AppDiagnostics.healthKitFailed(
                event: "authorization",
                error: error
            )
            return false
        }
        let authorized = canWrite
        AppDiagnostics.healthKitOutcome(
            event: "authorization",
            outcome: authorized ? "authorized" : "denied"
        )
        return authorized
    }

    /// Save one HKWorkout for a freshly archived session. No-ops
    /// unless every gate passes; never throws into the caller.
    /// Idempotent via `healthKitWorkoutUUID`.
    ///
    /// To prevent duplicate HKWorkouts, a sentinel UUID is persisted
    /// to SwiftData BEFORE the async HealthKit write begins. If the
    /// app is re-entered or relaunched before the HKWorkout finishes,
    /// the sentinel blocks a second write. On success the sentinel is
    /// replaced with the real HKWorkout UUID; on failure it is cleared
    /// so a future retry can attempt the write again.
    static func saveWorkout(for session: WorkoutSession, in context: ModelContext) {
        guard isEnabled else { return }
        guard isAvailable else {
            AppDiagnostics.healthKitOutcome(event: "save", outcome: "unavailable")
            return
        }
        guard canWrite else {
            AppDiagnostics.healthKitOutcome(event: "save", outcome: "unauthorized")
            return
        }
        guard session.healthKitWorkoutUUID == nil else {
            AppDiagnostics.healthKitOutcome(event: "save", outcome: "already_saved")
            return
        }
        guard session.completedAt != nil, session.totalSets > 0 else {
            AppDiagnostics.healthKitOutcome(event: "save", outcome: "ineligible")
            return
        }

        let start = session.startedAt
        let end = session.completedAt ?? Date()
        guard end > start else { return }

        // Pre-assign a sentinel UUID and persist it so re-entry or
        // relaunch can't create a duplicate HKWorkout.
        session.healthKitWorkoutUUID = UUID()
        do {
            try persistSentinel(in: context)
        } catch {
            session.healthKitWorkoutUUID = nil
            AppDiagnostics.healthKitFailed(event: "sentinel", error: error)
            return
        }

        Task {
            guard let workout = await build(start: start, end: end) else {
                session.healthKitWorkoutUUID = nil
                do {
                    try persistSentinel(in: context)
                } catch {
                    AppDiagnostics.healthKitFailed(event: "sentinel_clear", error: error)
                }
                return
            }
            session.healthKitWorkoutUUID = workout.uuid
            do {
                try persistSentinel(in: context)
                AppDiagnostics.healthKitOutcome(event: "save", outcome: "success")
            } catch {
                AppDiagnostics.healthKitFailed(event: "sentinel_finalize", error: error)
            }
        }
    }

    // MARK: - Internals

    /// Persist sentinel transitions without the app-wide rollback wrapper.
    /// A failed clear must leave the in-memory UUID nil so this process can
    /// retry; rolling back would restore the sentinel and suppress that retry.
    private static func persistSentinel(in context: ModelContext) throws {
        try context.save() // architecture: allow-direct-save -- sentinel failure semantics are handled locally
    }

    /// Build and finish the workout with no associated samples — just
    /// the activity type and time span. Returns the saved HKWorkout,
    /// or nil on any failure (logging must never break).
    private static func build(start: Date, end: Date) async -> HKWorkout? {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            return try await builder.finishWorkout()
        } catch {
            AppDiagnostics.healthKitFailed(event: "save", error: error)
            return nil
        }
    }
}

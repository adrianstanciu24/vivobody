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
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

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
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: [])
        } catch {
            return false
        }
        return canWrite
    }

    /// Save one HKWorkout for a freshly archived session. No-ops
    /// unless every gate passes; never throws into the caller.
    /// Idempotent via `healthKitWorkoutUUID`.
    static func saveWorkout(for session: WorkoutSession, in context: ModelContext) {
        guard isEnabled, isAvailable, canWrite,
              session.healthKitWorkoutUUID == nil,
              session.completedAt != nil,
              session.totalSets > 0
        else { return }

        let start = session.startedAt
        let end = session.completedAt ?? Date()
        guard end > start else { return }

        Task {
            guard let workout = await build(start: start, end: end) else { return }
            session.healthKitWorkoutUUID = workout.uuid
            try? context.save()
        }
    }

    // MARK: - Internals

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
            return nil
        }
    }
}

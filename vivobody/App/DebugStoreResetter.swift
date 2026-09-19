//
//  DebugStoreResetter.swift
//  vivobody
//
//  DEBUG-only clean-store fixture reset. Workout graphs are committed before
//  catalog dependencies are cleared, preserving the established delete order.
//

import Foundation
import SwiftData
import VivoKit

#if DEBUG

    @MainActor
    enum DebugStoreResetter {
        static func prepareDefaults(
            ifRequested request: DebugStoreResetRequest?,
            defaults: UserDefaults = .standard
        ) {
            guard let request else { return }
            defaults.set(
                !request.shouldShowOnboarding,
                forKey: SettingsKey.onboardingCompleted
            )
        }

        static func reset(
            ifRequested request: DebugStoreResetRequest?,
            in context: ModelContext,
            defaults: UserDefaults = .standard,
            sharedDefaults: UserDefaults? = UserDefaults(suiteName: WidgetShared.appGroup)
        ) {
            guard let request else { return }
            prepareDefaults(ifRequested: request, defaults: defaults)
            defaults.removeObject(forKey: SettingsKey.restNotificationsEnabled)
            defaults.removeObject(forKey: SettingsKey.hasSeenRestNotificationPrimer)
            deleteAll(WorkoutSession.self, in: context)
            deleteAll(WorkoutTemplate.self, in: context)
            deleteAll(BodyWeightEntry.self, in: context)
            // Persist workout deletion before clearing its catalog dependencies.
            try? context.saveOrRollback()
            deleteAll(ExerciseCatalogItem.self, in: context)
            CatalogDeletionTombstones.clear(in: defaults)
            CatalogLaunchReconciler.invalidate(in: defaults)
            sharedDefaults?.removeObject(forKey: WidgetShared.startWorkoutRequestKey)
            sharedDefaults?.removeObject(forKey: WidgetShared.completeSetRequestKey)
            sharedDefaults?.removeObject(forKey: WidgetShared.startTemplateWorkoutRequestKey)
            try? context.saveOrRollback()
        }

        private static func deleteAll(
            _ model: (some PersistentModel).Type,
            in context: ModelContext
        ) {
            // SwiftData's model delete executes in the persistent store. Avoid
            // materializing every historical graph on MainActor merely to mark
            // each instance for deletion during deterministic DEBUG setup.
            try? context.delete(model: model)
        }
    }

#endif

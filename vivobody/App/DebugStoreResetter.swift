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
        static func reset(
            ifRequested request: DebugStoreResetRequest?,
            in context: ModelContext,
            defaults: UserDefaults = .standard,
            sharedDefaults: UserDefaults? = UserDefaults(suiteName: WidgetShared.appGroup)
        ) {
            guard let request else { return }
            defaults.set(
                !request.shouldShowOnboarding,
                forKey: SettingsKey.onboardingCompleted
            )
            deleteAll(WorkoutSession.self, in: context)
            deleteAll(WorkoutTemplate.self, in: context)
            deleteAll(BodyWeightEntry.self, in: context)
            // Persist workout deletion before clearing its catalog dependencies.
            try? context.saveOrRollback()
            deleteAll(ExerciseCatalogItem.self, in: context)
            CatalogDeletionTombstones.clear(in: defaults)
            sharedDefaults?.removeObject(forKey: WidgetShared.startWorkoutRequestKey)
            sharedDefaults?.removeObject(forKey: WidgetShared.completeSetRequestKey)
            sharedDefaults?.removeObject(forKey: WidgetShared.startTemplateWorkoutRequestKey)
            try? context.saveOrRollback()
        }

        private static func deleteAll<T: PersistentModel>(
            _ model: T.Type,
            in context: ModelContext
        ) {
            let models = (try? context.fetch(FetchDescriptor<T>())) ?? []
            for model in models {
                context.delete(model)
            }
        }
    }

#endif

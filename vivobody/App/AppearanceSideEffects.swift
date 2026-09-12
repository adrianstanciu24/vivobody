//
//  AppearanceSideEffects.swift
//  vivobody
//
//  Mirrors Vivobody's appearance preference to external workout surfaces so
//  Home Screen widgets and an existing Live Activity update together.
//

import VivoKit

@MainActor
enum AppearanceSideEffects {
    static func sync(_ appearance: AppAppearance) {
        WidgetSnapshotWriter.writeAppearance(appearance)
        WorkoutLiveActivityController.updateAppearance(appearance)
    }
}

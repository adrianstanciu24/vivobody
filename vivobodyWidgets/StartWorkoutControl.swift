//
//  StartWorkoutControl.swift
//  vivobodyWidgets
//
//  A Control Center / Lock Screen / Action Button control that
//  starts today's workout. Reuses the existing StartTodaysWorkoutIntent
//  (shared WidgetIntents) which sets the App Group handoff flag and
//  opens the app. On iPhone 16+ the user assigns this in
//  Settings > Action Button > Control.
//

import AppIntents
import SwiftUI
import WidgetKit

struct StartWorkoutControl: ControlWidget {
    static let kind = WidgetShared.startWorkoutControlKind

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartTodaysWorkoutIntent()) {
                Label("Start Workout", systemImage: "figure.run")
            }
        }
        .displayName("Start Workout")
        .description("Start today's vivobody workout.")
    }
}

//
//  ActiveWorkoutLiveActivity.swift
//  vivobodyWidgets
//
//  The Live Activity + Dynamic Island surface for an in-progress
//  workout. Shows the current exercise, set number, set spec, and
//  a rest-timer countdown when resting.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct ActiveWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            ActiveWorkoutActivityView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(Tint.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isResting {
                        restTimerBlock(context.state)
                    } else {
                        setSpecBlock(context.state)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.exerciseName)
                            .font(Typography.headline)
                            .lineLimit(1)
                        Text("Set \(context.state.setNumber)/\(context.state.plannedSets)")
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                        if !context.state.isResting {
                            Button(intent: CompleteActiveSetIntent()) {
                                Text("Complete")
                                    .font(Typography.caption)
                            }
                            .buttonStyle(.glass)
                            .tint(Tint.primary)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(Tint.primary).frame(width: 6, height: 6)
                    if !context.state.isResting {
                        Text("\(context.state.setNumber)/\(context.state.plannedSets)")
                            .font(Typography.metricUnit)
                            .monospacedDigit()
                    }
                }
            } compactTrailing: {
                restOrSetValue(context.state)
            } minimal: {
                Circle().fill(Tint.primary).frame(width: 7, height: 7)
            }
        }
    }

    @ViewBuilder
    private func restOrSetValue(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        if state.isResting, let restEndsAt = state.restEndsAt {
            Text(timerInterval: Date()...restEndsAt, countsDown: true)
                .font(Typography.metricUnit)
                .monospacedDigit()
        } else {
            Text("\(state.setNumber)/\(state.plannedSets)")
                .font(Typography.metricUnit)
                .monospacedDigit()
        }
    }

    private func restTimerBlock(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let restEndsAt = state.restEndsAt {
                Text(timerInterval: Date()...restEndsAt, countsDown: true)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                ProgressView(timerInterval: Date()...restEndsAt, countsDown: true)
                    .tint(Tint.inProgress)
                    .frame(width: 92)
            }
        }
    }

    private func setSpecBlock(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.setSpec)
                .font(Typography.statValue)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Set \(state.setNumber) of \(state.plannedSets)")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.secondary)
        }
    }
}

struct ActiveWorkoutActivityView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(state.exerciseName)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
                .lineLimit(1)

            if state.isResting, let restEndsAt = state.restEndsAt {
                Text(timerInterval: Date()...restEndsAt, countsDown: true)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                ProgressView(timerInterval: Date()...restEndsAt, countsDown: true)
                    .tint(Tint.inProgress)
                    .frame(height: 3)
                Text("Set \(state.setNumber) of \(state.plannedSets)")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
            } else {
                Text(state.exerciseName)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text("Set \(state.setNumber) of \(state.plannedSets)")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                HStack(alignment: .center, spacing: Space.md) {
                    Text(state.setSpec)
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: Space.sm)
                    Button(intent: CompleteActiveSetIntent()) {
                        Text("Complete")
                            .font(Typography.headline)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Tint.primary)
                }
            }
        }
        .padding()
        .dynamicTypeSize(.large)
    }
}

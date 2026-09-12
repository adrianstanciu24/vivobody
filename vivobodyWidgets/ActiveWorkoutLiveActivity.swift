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
import UIKit
import VivoKit
import WidgetKit

/// A countdown range that never traps: skip-to-zero pushes a rest
/// deadline at (or, by render time, just before) now, and
/// ClosedRange requires lowerBound <= upperBound.
private func restTimerRange(endingAt end: Date) -> ClosedRange<Date> {
    let now = Date()
    return now ... max(now, end)
}

struct ActiveWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            ActiveWorkoutActivityView(state: context.state)
        } dynamicIsland: { context in
            let island = DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Group {
                        if context.state.isResting {
                            restTimerBlock(context.state)
                        } else {
                            setSpecBlock(context.state)
                        }
                    }
                    .environment(\.colorScheme, .dark)
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
                            if context.state.isExerciseComplete {
                                Label("Done", systemImage: "checkmark")
                                    .font(Typography.caption)
                                    .foregroundStyle(Tint.complete)
                            } else {
                                Button(intent: CompleteActiveSetIntent()) {
                                    Text("Complete")
                                        .font(Typography.caption)
                                }
                                .buttonStyle(.glass)
                                .tint(Tint.primary)
                            }
                        }
                    }
                    .environment(\.colorScheme, .dark)
                }
            } compactLeading: {
                Text("SET \(context.state.setNumber)/\(context.state.plannedSets)")
                    .font(Typography.metricUnit)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .overlay(alignment: .leading) {
                        if context.state.isResting {
                            RestTransitionArrow()
                                .offset(x: -(Space.xl + Space.sm))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .environment(\.colorScheme, .dark)
            } compactTrailing: {
                Group {
                    if context.state.isResting {
                        HStack(spacing: Space.lg) {
                            Circle()
                                .fill(Tint.primary)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            restTimerValue(context.state)
                        }
                    } else {
                        Circle()
                            .fill(Tint.primary)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .environment(\.colorScheme, .dark)
            } minimal: {
                Circle().fill(Tint.primary).frame(width: 7, height: 7)
                    .environment(\.colorScheme, .dark)
            }
            if context.state.isResting {
                return island
                    .contentMargins(.leading, 38, for: .compactLeading)
                    .contentMargins(.leading, 4, for: .compactTrailing)
                    .contentMargins(.trailing, 0, for: .compactTrailing)
            }
            return island
                .contentMargins(.leading, Space.lg, for: .compactLeading)
                .contentMargins(.trailing, Space.lg, for: .compactTrailing)
        }
    }

    @ViewBuilder
    private func restTimerValue(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        if let restEndsAt = state.restEndsAt {
            Text(timerInterval: restTimerRange(endingAt: restEndsAt), countsDown: true)
                .font(Typography.metricUnit)
                .monospacedDigit()
        }
    }

    private func restTimerBlock(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let restEndsAt = state.restEndsAt {
                let range = restTimerRange(endingAt: restEndsAt)
                Text(timerInterval: range, countsDown: true)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                ProgressView(timerInterval: range, countsDown: true)
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

private struct RestTransitionArrow: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(Typography.caption)
            .foregroundStyle(Tint.primary)
            .accessibilityHidden(true)
    }
}

struct ActiveWorkoutActivityView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    let state: WorkoutActivityAttributes.ContentState

    private var effectiveColorScheme: ColorScheme {
        switch state.appearance ?? .system {
        case .system: systemColorScheme
        case .light: .light
        case .dark: .dark
        }
    }

    private var background: Color {
        effectiveColorScheme == .dark
            ? .black
            : .white
    }

    var body: some View {
        content
            .environment(\.colorScheme, effectiveColorScheme)
            .activityBackgroundTint(background)
            .activitySystemActionForegroundColor(Tint.primary)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if state.isResting, let restEndsAt = state.restEndsAt {
                Text(state.exerciseName)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                let range = restTimerRange(endingAt: restEndsAt)
                Text(timerInterval: range, countsDown: true)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                // Empty labels: the default currentValueLabel repeats the
                // countdown under the bar, duplicating the hero timer.
                ProgressView(timerInterval: range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(Tint.inProgress)
                .frame(height: 3)
                Text("Set \(state.setNumber) of \(state.plannedSets)")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
            } else {
                Text(state.exerciseName)
                    .font(Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text("Set \(state.setNumber) of \(state.plannedSets)")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
                HStack(alignment: .center, spacing: Space.md) {
                    Text(state.setSpec)
                        .font(Typography.statValue)
                        .fontWeight(.heavy)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: Space.sm)
                    if state.isExerciseComplete {
                        Label("Done", systemImage: "checkmark")
                            .font(Typography.headline)
                            .foregroundStyle(Tint.complete)
                            .frame(minHeight: 36)
                    } else {
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
        }
        .padding()
    }
}

//
//  ActiveExerciseCardStates.swift
//  vivobody
//
//  Honest non-live states and the thumb-reachable action area for the active
//  exercise instrument. Empty exercises remain recoverable and never borrow
//  the completed exercise's gold treatment or summary values.
//

import SwiftUI
import VivoKit

extension ActiveExerciseCard {
    // MARK: - Empty

    var emptyExerciseHero: some View {
        Text("No sets")
            .font(Typography.display)
            .foregroundStyle(Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("emptyExerciseState")
    }

    var addFirstSetAction: some View {
        Button {
            addSet()
        } label: {
            HStack(spacing: Space.md) {
                Text("Add set")
                Spacer()
                Image(systemName: "plus")
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityLabel("Add a set")
        .accessibilityHint("Creates the first set using this exercise's planned values")
        .accessibilityIdentifier("addFirstSetButton")
    }

    // MARK: - Completed hero

    /// Exercise finished — show the top set, locked in gold, static.
    @ViewBuilder
    var completedHero: some View {
        let top = sets.last(where: { $0.isCompleted }) ?? sets.last
        switch exercise.trackingMode {
        case .reps:
            completedRepsHero(top)
        case .duration:
            completedDurationHero(top)
        }
    }

    @ViewBuilder
    func completedRepsHero(_ top: WorkoutSet?) -> some View {
        if isUnloadedBodyweightExercise {
            completedUnloadedRepsHero(top)
        } else {
            completedLoadedRepsHero(top)
        }
    }

    func completedUnloadedRepsHero(_ top: WorkoutSet?) -> some View {
        let repsText = top.map { "\($0.reps)" } ?? "—"
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("REPS")
                .panelLegend()
                .accessibilityHidden(true)
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(repsText)
                    .font(.system(size: 104, weight: .bold))
                    .foregroundStyle(Tint.complete)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                Text("reps")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(repsText) reps")
    }

    func completedLoadedRepsHero(_ top: WorkoutSet?) -> some View {
        let weightText = top.flatMap {
            exercise.loadMode.summaryLoadLabel($0.weight, unit: unit)
        } ?? "—"
        let repsText = top.map { "\($0.reps)" } ?? "—"
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text(weightText)
                .font(.system(size: 104, weight: .bold))
                .foregroundStyle(Tint.complete)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.35)
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("×")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                Text(repsText)
                    .font(Typography.metricLg)
                    .foregroundStyle(Tint.complete.opacity(Opacity.strong))
                    .monospacedDigit()
                Text("reps")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    func completedDurationHero(_ top: WorkoutSet?) -> some View {
        let timeText = top.map { DurationFormatter.string($0.duration) } ?? "—"
        let loadText = top.flatMap {
            exercise.loadMode.summaryLoadLabel($0.weight, unit: unit)
        }
        let accessibilityLoad = top.flatMap {
            exercise.loadMode.accessibilityLoadDescription($0.weight, unit: unit)
        }
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text(exercise.modality.durationLabel)
                .panelLegend()
            Text(timeText)
                .font(.system(size: 104, weight: .bold))
                .foregroundStyle(Tint.complete)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let loadText {
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text(loadText)
                        .font(Typography.metricLg)
                        .foregroundStyle(Tint.complete.opacity(Opacity.strong))
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(exercise.modality.durationLabel) \(timeText)"
                + (accessibilityLoad.map { ", \($0)" } ?? "")
        )
    }

    // MARK: - Action

    @ViewBuilder
    var actionArea: some View {
        if sets.isEmpty {
            addFirstSetAction
        } else if let active = session.activeSet(for: exercise) {
            let isLastSet = activeIndex == sets.count - 1
            let durationAccessibilityLabel = "\(exercise.modality.durationLabel) \(DurationFormatter.string(active.duration))"
                + (exercise.loadMode.accessibilityLoadDescription(active.weight, unit: unit)
                    .map { ", \($0)" } ?? "")
            SetCompleteButton(
                reps: active.reps,
                weight: active.weight,
                loadMode: exercise.loadMode,
                isComplete: pendingCompletionSetID == active.id,
                intensity: isLastSet ? .peak : .standard,
                title: completeTitle(isLastSet: isLastSet),
                accessibilityLabelOverride: exercise.trackingMode == .duration
                    ? durationAccessibilityLabel
                    : nil,
                onToggle: { handleSetToggle(active) }
            )
            .accessibilityIdentifier("completeSetButton")
        } else {
            // Panel discipline: the completion line occupies exactly the
            // SetCompleteButton's slot, so finishing changes what's lit.
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise complete")
                    .font(Typography.title)
                    .foregroundStyle(Tint.complete)
                Spacer()
                Text("Swipe for next  →")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize ? 96 : 72,
                idealHeight: 96,
                maxHeight: dynamicTypeSize.isAccessibilitySize ? .infinity : 96
            )
        }
    }
}

//
//  ActiveExerciseEffortActionArea.swift
//  vivobody
//
//  Focused RIR and primary-action leaves for the active exercise card.
//  Eligibility and action copy are precomputed; bindings and UUID actions
//  keep mutation ownership with ActiveExerciseCard.
//

import SwiftUI
import VivoKit

struct ActiveExerciseEffortSection: View {
    let input: ActiveExerciseEffortActionInput
    @Binding var rir: Int

    var body: some View {
        if input.showsRIRControl {
            RIRSelector(value: $rir)
        }
    }
}

struct ActiveExerciseActionArea: View {
    let input: ActiveExerciseEffortActionInput
    let dynamicTypeSize: DynamicTypeSize
    let addSet: () -> Void
    let completeSet: (UUID) -> Void

    var body: some View {
        switch input.primaryAction {
        case .addFirstSet:
            addFirstSetAction
        case let .complete(button):
            SetCompleteButton(
                reps: button.reps,
                weight: button.weight,
                loadMode: button.loadMode,
                isComplete: button.isPending,
                intensity: button.isLastSet ? .peak : .standard,
                title: button.title,
                accessibilityLabelOverride: button.accessibilityLabelOverride,
                onToggle: { completeSet(button.setID) }
            )
            .accessibilityIdentifier("completeSetButton")
        case .exerciseComplete:
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

    private var addFirstSetAction: some View {
        Button(action: addSet) {
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
}

struct ActiveExerciseEmptyInstrument: View {
    var body: some View {
        Text("No sets")
            .font(Typography.display)
            .foregroundStyle(Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("emptyExerciseState")
    }
}

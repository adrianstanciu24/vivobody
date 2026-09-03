//
//  ActiveExerciseIdentitySection.swift
//  vivobody
//
//  Focused identity, set-timeline, and set-count controls for the active
//  exercise instrument. It consumes immutable values and emits UUID actions.
//

import SwiftUI
import VivoKit

struct ActiveSetIndicatorActions {
    let tapCompleted: (UUID) -> Void
    let edit: (UUID) -> Void
    let delete: (UUID) -> Void
    let remove: (UUID) -> Void
}

struct ActiveExerciseConfigurationActions {
    let addSet: () -> Void
    let removeSet: (UUID) -> Void
    let selectWeightStep: (Double) -> Void
}

struct ActiveExerciseNameSection<MenuContent: View>: View {
    let input: ActiveExerciseIdentityInput
    let dynamicTypeSize: DynamicTypeSize
    let menu: () -> MenuContent

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let tag = input.supersetTag {
                Text("Superset · \(tag)")
                    .panelLegendType()
                    .foregroundStyle(Tint.inProgress)
                    .accessibilityLabel("Superset, position \(tag)")
            }
            Text(input.name)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.7 : 0.82)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu { menu() }
    }
}

struct ActiveSetStatusSection: View {
    let input: ActiveExerciseIdentityInput
    let actions: ActiveSetIndicatorActions

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.md) {
                ForEach(input.sets) { set in
                    indicator(set)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func indicator(_ set: ActiveSetIndicatorInput) -> some View {
        let pipView = LEDLamp(
            state: lampState(for: set.status),
            reading: set.visibleReading
        )
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Set \(set.number)")
        .accessibilityValue(set.accessibilityValue)
        .accessibilityAddTraits(set.status == .current ? .isSelected : [])

        switch set.status {
        case .completed:
            pipView
                .onTapGesture { actions.tapCompleted(set.id) }
                .contextMenu {
                    Button {
                        actions.edit(set.id)
                    } label: {
                        Label("Edit set", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        actions.delete(set.id)
                    } label: {
                        Label("Delete set", systemImage: "trash")
                    }
                }
                .accessibilityAction { actions.edit(set.id) }
                .accessibilityAction(named: "Edit set") { actions.edit(set.id) }
                .accessibilityAction(named: "Delete set") { actions.delete(set.id) }
                .accessibilityHint("Double tap to edit this set")
        case .current, .pending:
            if set.canRemove {
                pipView
                    .contextMenu {
                        Button(role: .destructive) {
                            actions.remove(set.id)
                        } label: {
                            Label("Remove set", systemImage: "minus.circle")
                        }
                    }
                    .accessibilityAction(named: "Remove set") {
                        actions.remove(set.id)
                    }
            } else {
                pipView
            }
        }
    }

    private func lampState(for status: ActiveSetIndicatorStatus) -> LEDLampState {
        switch status {
        case .completed: .lit
        case .current: .armed
        case .pending: .off
        }
    }
}

struct ActiveExerciseConfigurationSection: View {
    let input: ActiveExerciseConfigurationInput
    let actions: ActiveExerciseConfigurationActions

    var body: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(input.setLegend)
                    .panelLegend()
                    .accessibilityHidden(true)
                setCountControls
            }

            if let increment = input.weightIncrement {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("STEP")
                        .panelLegend()
                        .accessibilityHidden(true)
                    weightStepButton(increment)
                }
            }
        }
    }

    private var setCountControls: some View {
        HStack(spacing: 0) {
            removeSetButton

            Text("\(input.setCount)")
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .frame(minWidth: 22)
                .accessibilityHidden(true)

            addSetButton
        }
        .coloredGlassControl(cornerRadius: Radius.pill)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var addSetButton: some View {
        Button(action: actions.addSet) {
            Image(systemName: "plus")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a set")
        .accessibilityInputLabels([Text("Add a set"), Text("Add Set"), Text("Add")])
    }

    private var removeSetButton: some View {
        Button {
            guard let setID = input.removableSetID else { return }
            actions.removeSet(setID)
        } label: {
            Image(systemName: "minus")
                .font(Typography.sectionLabel)
                .foregroundStyle(
                    input.removableSetID == nil ? Ink.quaternary : Ink.tertiary
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(input.removableSetID == nil)
        .accessibilityLabel("Remove a set")
        .accessibilityInputLabels([Text("Remove a set"), Text("Remove Set"), Text("Remove")])
    }

    private func weightStepButton(_ increment: ActiveWeightIncrementInput) -> some View {
        let setStepperWidth = (Space.tapMin * 2) + 22
        return Button {
            actions.selectWeightStep(increment.next())
        } label: {
            Text(increment.label)
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.md)
                .frame(minWidth: setStepperWidth, minHeight: Space.tapMin)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .coloredGlassControl(cornerRadius: Radius.pill)
        .accessibilityLabel("Weight increment")
        .accessibilityValue(increment.label)
        .accessibilityHint("Cycles through the available increments")
    }
}

//
//  ActiveExerciseIdentitySection.swift
//  vivobody
//
//  Focused identity, set-timeline, set-count stepper, and step-increment
//  menu for the active exercise instrument. It consumes immutable values and
//  emits UUID actions.
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
    let selectStep: (Double) -> Void
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
            : AnyLayout(HStackLayout(spacing: Space.lg))
        layout {
            if !input.sets.isEmpty {
                Text(progressLabel)
                    .font(Typography.sectionLabel)
                    .monospacedDigit()
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            timeline
        }
    }

    private var progressLabel: String {
        if let current = input.sets.first(where: { $0.status == .current }) {
            return "Set \(current.number) of \(input.sets.count)"
        }
        let completed = input.sets.count(where: { $0.status == .completed })
        return "\(completed) of \(input.sets.count) complete"
    }

    private var timeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
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
            shape: .segment,
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
                    .panelLegendType()
                    .foregroundStyle(Ink.secondary)
                    .accessibilityHidden(true)
                setCountControls
            }

            if let increment = input.stepIncrement {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("STEP")
                        .panelLegendType()
                        .foregroundStyle(Ink.secondary)
                        .accessibilityHidden(true)
                    stepButton(increment)
                }
            }
        }
    }

    private var setCountControls: some View {
        HStack(spacing: 0) {
            setCountButton("minus", action: removeSetAction)

            Text("\(input.setCount)")
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .frame(minWidth: 22)

            setCountButton("plus", action: actions.addSet)
        }
        .coloredGlassControl(cornerRadius: Radius.pill)
        .fixedSize(horizontal: true, vertical: false)
        // The native Stepper's segments are shorter than 44pt, so it serves
        // only as the accessibility element over the 44pt visual buttons.
        .accessibilityRepresentation {
            Stepper("Sets", value: setCountBinding, in: setCountRange)
                .accessibilityInputLabels([Text("Sets"), Text("Set count")])
        }
    }

    private var setCountBinding: Binding<Int> {
        Binding(
            get: { input.setCount },
            set: { newCount in
                if newCount > input.setCount {
                    actions.addSet()
                } else if newCount < input.setCount {
                    removeSetAction?()
                }
            }
        )
    }

    /// Pins the lower bound to the current count when no set can be removed,
    /// which disables the Stepper's decrement.
    private var setCountRange: ClosedRange<Int> {
        (input.removableSetID == nil ? input.setCount : 0) ... Int.max
    }

    private func setCountButton(_ systemImage: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
                .font(Typography.sectionLabel)
                .foregroundStyle(action == nil ? Ink.quaternary : Ink.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var removeSetAction: (() -> Void)? {
        guard let setID = input.removableSetID else { return nil }
        let removeSet = actions.removeSet
        return { removeSet(setID) }
    }

    private func stepButton(_ increment: ActiveStepIncrementInput) -> some View {
        let setStepperWidth = (Space.tapMin * 2) + 22
        let selection = Binding(
            get: { increment.selected },
            set: { actions.selectStep($0) }
        )
        return Menu {
            Picker(increment.accessibilityLabel, selection: selection) {
                ForEach(increment.options, id: \.self) { option in
                    Text(increment.label(for: option)).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Text(increment.label)
                .font(Typography.metricUnit)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.md)
                .frame(minWidth: setStepperWidth, minHeight: Space.tapMin)
                .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .coloredGlassControl(cornerRadius: Radius.pill)
        .accessibilityLabel(increment.accessibilityLabel)
        .accessibilityValue(increment.accessibilityValue)
        .accessibilityHint("Shows the available increments")
    }
}

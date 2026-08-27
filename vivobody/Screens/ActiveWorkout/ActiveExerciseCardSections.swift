//
//  ActiveExerciseCardSections.swift
//  vivobody
//
//  Section view builders for ActiveExerciseCard: identity, the working-set
//  instrument, RIR, and actions.
//

import SwiftData
import SwiftUI
import VivoKit

extension ActiveExerciseCard {
    // MARK: - Name + pips

    var nameRow: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // Shared ribbon for every linked card, using lifter-standard notation.
            if let tag = session.supersetTag(for: exercise) {
                Text("Superset · \(tag)")
                    .panelLegendType()
                    .foregroundStyle(Tint.inProgress)
                    .accessibilityLabel("Superset, position \(tag)")
            }
            Text(exercise.name)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.7 : 0.82)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // The top bar owns the visible options pill; long-pressing the
        // exercise identity remains the power-user shortcut to the same menu.
        .contextMenu { exerciseMenu }
    }

    var setPips: some View {
        // The newest completed lamp carries its reading; older sets compress to dots.
        let lastCompletedID = sets.last(where: { $0.isCompleted })?.id
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.md) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                    let isActiveSet = idx == activeIndex
                    let pipView = pip(
                        isCompleted: set.isCompleted,
                        isActive: isActiveSet,
                        reading: set.id == lastCompletedID
                            ? exercise.setLabel(set, unit: unit)
                            : nil
                    )
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Set \(idx + 1)")
                    .accessibilityValue(
                        set.isCompleted
                            ? "Completed, \(exercise.setLabel(set, unit: unit))"
                            : (isActiveSet ? "Current" : "Pending")
                    )
                    .accessibilityAddTraits(isActiveSet ? .isSelected : [])
                    // Completed sets tap to edit (long-press adds delete);
                    // pending sets can be removed when more than one exists.
                    if set.isCompleted {
                        pipView
                            .onTapGesture {
                                Haptics.selection()
                                editingSet = set
                            }
                            .contextMenu { pipMenu(for: set) }
                            .accessibilityAction { editingSet = set }
                            .accessibilityAction(named: "Edit set") { editingSet = set }
                            .accessibilityAction(named: "Delete set") { deletingSet = set }
                            .accessibilityHint("Double tap to edit this set")
                    } else if sets.count > 1 {
                        pipView
                            .contextMenu { pipMenu(for: set) }
                            .accessibilityAction(named: "Remove set") { removeSet(set) }
                    } else {
                        pipView
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Per-set long-press menu, surfaced from the pips. Completed sets
    /// can be edited or deleted; a pending set can be removed outright
    /// (so long as it isn't the only one).
    @ViewBuilder
    func pipMenu(for set: WorkoutSet) -> some View {
        if set.isCompleted {
            Button {
                editingSet = set
            } label: {
                Label("Edit set", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingSet = set
            } label: {
                Label("Delete set", systemImage: "trash")
            }
        } else if sets.count > 1 {
            Button(role: .destructive) {
                removeSet(set)
            } label: {
                Label("Remove set", systemImage: "minus.circle")
            }
        }
    }

    /// Set-count stepper used in the configuration cluster below the
    /// lamps. Its legend lives above the capsule (see
    /// `exerciseConfigurationRow`), matching the RIR selector's
    /// legend-over-control treatment. Keeping the stepper in its own
    /// glass capsule prevents plus/minus glyphs from reading as two
    /// more set-status indicators.
    var setCountControls: some View {
        HStack(spacing: 0) {
            removeSetButton

            Text("\(sets.count)")
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

    /// One-tap "add a set." Tapping it appends a set seeded from the
    /// current working set, so "one more" matches the weight already
    /// being lifted. Adding to a finished exercise re-opens it.
    var addSetButton: some View {
        Button {
            addSet()
        } label: {
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

    /// One-tap removal for the final pending set. Completed sets stay
    /// protected behind their existing context-menu delete flow, and
    /// an exercise always retains at least one set.
    var removeSetButton: some View {
        let removableSet = sets.last(where: { !$0.isCompleted })
        let canRemove = sets.count > 1 && removableSet != nil

        return Button {
            guard let removableSet else { return }
            removeSet(removableSet)
        } label: {
            Image(systemName: "minus")
                .font(Typography.sectionLabel)
                .foregroundStyle(canRemove ? Ink.tertiary : Ink.quaternary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canRemove)
        .accessibilityLabel("Remove a set")
        .accessibilityInputLabels([Text("Remove a set"), Text("Remove Set"), Text("Remove")])
    }

    /// Set pips as LED lamps: pending is an unlit outline, the active
    /// set is armed (standby breathe), a completed set fills —
    /// completing one overdrives the lamp past resting brightness
    /// before it settles with an afterglow, in the same frame as the
    /// crescendo. The newest completed lamp stretches into a readout
    /// capsule carrying its logged value.
    func pip(isCompleted: Bool, isActive: Bool, reading: String? = nil) -> some View {
        LEDLamp(
            state: isCompleted ? .lit : (isActive ? .armed : .off),
            reading: reading
        )
    }

    // MARK: - Hero

    var heroBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            exerciseConfigurationRow

            SectionDivider()
                .padding(.vertical, Space.lg)

            if sets.isEmpty {
                emptyExerciseHero
            } else if session.activeSet(for: exercise) != nil {
                switch exercise.trackingMode {
                case .reps: repsHero
                case .duration: durationHero
                }
            } else {
                completedHero
            }
        }
    }

    /// Set count and, when load is editable, its increment. Completed,
    /// duration, and no-load bodyweight exercises retain only set count.
    var exerciseConfigurationRow: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(sets.count == 1 ? "SET" : "SETS")
                    .panelLegend()
                    .accessibilityHidden(true)
                setCountControls
            }

            if session.activeSet(for: exercise) != nil,
               exercise.trackingMode == .reps,
               !isUnloadedBodyweightExercise
            {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("STEP")
                        .panelLegend()
                        .accessibilityHidden(true)
                    stepToggle
                }
            }
        }
    }

    /// Weight × reps instrument. Bodyweight movements keep `BW` as the
    /// stable hero and demote the added-load encoder beside it; ordinary
    /// external-load work keeps the logged weight as the hero.
    @ViewBuilder
    var repsHero: some View {
        if exercise.loadMode == .bodyweightAdded {
            bodyweightRepsHero
        } else if isUnloadedBodyweightExercise {
            unloadedRepsHero
        } else {
            externalLoadRepsHero
        }
    }

    var externalLoadRepsHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if exercise.loadMode == .assistanceSubtracted
                || exercise.loadMode == .nonComparable
            {
                Text(exercise.loadMode.inputLabel)
                    .panelLegend()
            }
            resistanceAccessibleLoadControl {
                BareScrubber(
                    value: weightDisplayBinding,
                    range: unit.strengthRange,
                    step: weightStep,
                    pointsPerStep: 8,
                    fontSize: activeLoadFontSize,
                    unit: activeLoadUnit,
                    unitFontSize: 18,
                    numberColor: Ink.primary,
                    unitColor: Ink.tertiary,
                    formatter: activeLoadFormatter,
                    accessibilityLabel: exercise.loadMode.inputLabel,
                    showsScrubHint: isActive,
                    performsScrubNudge: isActive,
                    fitsWidth: true,
                    tickTone: .deep,
                    hitSlop: 12,
                    showsRail: true,
                    cancellationID: effectiveScrubCancellationID,
                    onScrubEnded: activeScrubDidEnd
                )
            }
            assistanceDirectionHint

            HStack(alignment: .center, spacing: Space.sm) {
                Text("×")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: repsBinding,
                    range: 1 ... 30,
                    step: 1,
                    pointsPerStep: 16,
                    fontSize: 46,
                    unit: "reps",
                    unitFontSize: 14,
                    numberColor: Ink.primary.opacity(Opacity.strong),
                    unitColor: Ink.tertiary,
                    accessibilityLabel: "Reps",
                    showsScrubHint: isActive,
                    hitSlop: 18,
                    showsRail: true,
                    railClearance: 26,
                    cancellationID: effectiveScrubCancellationID,
                    onScrubEnded: activeScrubDidEnd
                )
                Spacer(minLength: 0)
            }
        }
    }

    /// Bodyweight is the resistance users performed against; zero in the
    /// model means no load was added, not a zero-load set. The compact
    /// encoder stays fully interactive so weighted variations use the same
    /// vertical scrub gesture without replacing or moving the `BW` hero.
    var bodyweightRepsHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bodyweight")
                    .panelLegend()
                Spacer(minLength: Space.lg)
                Text("Added load")
                    .panelLegend()
            }

            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("BW")
                    .font(Typography.bigMetric)
                    .foregroundStyle(Ink.primary)
                    .monospaced()
                    .accessibilityLabel("Bodyweight")

                Spacer(minLength: Space.lg)

                Text("+")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: weightDisplayBinding,
                    range: unit.strengthRange,
                    step: weightStep,
                    pointsPerStep: 8,
                    fontSize: 40,
                    unit: unit.symbol,
                    unitFontSize: 13,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: exercise.loadMode.inputLabel,
                    showsScrubHint: isActive,
                    performsScrubNudge: isActive,
                    tickTone: .deep,
                    hitSlop: 18,
                    cancellationID: effectiveScrubCancellationID,
                    onScrubEnded: activeScrubDidEnd
                )
            }

            HStack(alignment: .center, spacing: Space.sm) {
                Text("×")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: repsBinding,
                    range: 1 ... 30,
                    step: 1,
                    pointsPerStep: 16,
                    fontSize: 46,
                    unit: "reps",
                    unitFontSize: 14,
                    numberColor: Ink.primary.opacity(Opacity.strong),
                    unitColor: Ink.tertiary,
                    accessibilityLabel: "Reps",
                    showsScrubHint: isActive,
                    hitSlop: 18,
                    showsRail: true,
                    railClearance: 26,
                    cancellationID: effectiveScrubCancellationID,
                    onScrubEnded: activeScrubDidEnd
                )
                Spacer(minLength: 0)
            }
        }
    }

    /// Timed instrument — the big number is the target duration
    /// (mm:ss). Isometric work is a hold; invalid legacy combinations
    /// retain neutral time wording.
    var durationHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(exercise.modality.durationLabel)
                .panelLegend()
            BareScrubber(
                value: durationBinding,
                range: DurationFormatter.scrubRange,
                step: DurationFormatter.scrubStep,
                pointsPerStep: 10,
                fontSize: 104,
                numberColor: Ink.primary,
                formatter: { DurationFormatter.string($0) },
                accessibilityLabel: exercise.modality.durationLabel,
                showsScrubHint: isActive,
                performsScrubNudge: isActive,
                fitsWidth: true,
                hitSlop: 12,
                showsRail: true,
                cancellationID: effectiveScrubCancellationID,
                onScrubEnded: activeScrubDidEnd
            )

            durationLoadControl
        }
    }

    @ViewBuilder
    var durationLoadControl: some View {
        if isUnloadedBodyweightExercise {
            EmptyView()
        } else if exercise.loadMode == .bodyweightAdded {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Bodyweight")
                        .panelLegend()
                    Spacer(minLength: Space.lg)
                    Text("Added load")
                        .panelLegend()
                }
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text("BW")
                        .font(Typography.metricLg)
                        .foregroundStyle(Ink.secondary)
                        .monospaced()
                        .accessibilityLabel("Bodyweight")
                    Spacer(minLength: Space.lg)
                    Text("+")
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                    BareScrubber(
                        value: weightDisplayBinding,
                        range: unit.strengthRange,
                        step: weightStep,
                        pointsPerStep: 8,
                        fontSize: 32,
                        unit: unit.symbol,
                        unitFontSize: 13,
                        numberColor: Ink.secondary,
                        unitColor: Ink.tertiary,
                        accessibilityLabel: exercise.loadMode.inputLabel,
                        showsScrubHint: isActive,
                        tickTone: .deep,
                        hitSlop: 18,
                        cancellationID: effectiveScrubCancellationID,
                        onScrubEnded: activeScrubDidEnd
                    )
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Space.xs) {
                if exercise.loadMode == .assistanceSubtracted
                    || exercise.loadMode == .nonComparable
                {
                    Text(exercise.loadMode.inputLabel)
                        .panelLegend()
                }
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    if exercise.loadMode != .nonComparable {
                        Text(exercise.loadMode.inputOperatorSymbol)
                            .font(Typography.statValue)
                            .foregroundStyle(Ink.quaternary)
                            .accessibilityHidden(true)
                    }
                    resistanceAccessibleLoadControl {
                        BareScrubber(
                            value: weightDisplayBinding,
                            range: unit.strengthRange,
                            step: weightStep,
                            pointsPerStep: 8,
                            fontSize: 46,
                            unit: activeLoadUnit,
                            unitFontSize: 14,
                            numberColor: Ink.secondary,
                            unitColor: Ink.tertiary,
                            formatter: activeLoadFormatter,
                            accessibilityLabel: exercise.loadMode.inputLabel,
                            showsScrubHint: isActive,
                            tickTone: .deep,
                            hitSlop: 18,
                            cancellationID: effectiveScrubCancellationID,
                            onScrubEnded: activeScrubDidEnd
                        )
                    }
                }
                assistanceDirectionHint
            }
        }
    }

    @ViewBuilder
    var assistanceDirectionHint: some View {
        if exercise.loadMode == .assistanceSubtracted {
            Text("Less assistance = harder")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("assistanceDirectionHint")
        }
    }

    // MARK: - RIR

    var showsRIRControl: Bool {
        exercise.trackingMode == .reps
            && exercise.modality == .dynamicStrength
            && session.activeSet(for: exercise) != nil
    }

    /// One open instrument field aligns every working-set adjustment on black.
    /// Quiet rules create configuration, readout, and effort zones without a
    /// boxed group competing with the primary action. The flexible stage keeps
    /// the available controls centered when a capability such as RIR is absent.
    func instrumentArea(expandsVertically: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBlock
                .powerOn(2, animated: isActive)

            if showsRIRControl {
                SectionDivider()
                    .padding(.vertical, Space.xl)
                rirControl
                    .powerOn(3, animated: isActive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.lg)
        .frame(
            maxWidth: .infinity,
            maxHeight: expandsVertically ? .infinity : nil,
            alignment: .center
        )
    }

    /// Reps-in-reserve is actionable only for a live dynamic-strength
    /// repetition set. Other modalities omit the control entirely so
    /// the flexible layout can reclaim its space instead of presenting
    /// a capability-shaped hole.
    @ViewBuilder
    var rirControl: some View {
        if showsRIRControl {
            RIRSelector(value: rirBinding)
        }
    }

    /// Small pill showing the weight increment, named by the legend
    /// above it rather than a label inside. Tap cycles through the
    /// unit's offered steps (1 / 1.25 / 2.5 / 5 for kg, 1 / 2.5 / 5 /
    /// 10 for lb). It sits beside the set stepper in the configuration
    /// cluster, directly above the load it controls, and shares the
    /// stepper's width so the two instruments read as a pair.
    var stepToggle: some View {
        let options = unit.strengthStepOptions
        let setStepperWidth = (Space.tapMin * 2) + 22
        let label = weightStep.formatted(
            .number.precision(.fractionLength(0 ... 2))
        ) + " \(unit.symbol)"
        return Button {
            let idx = options.firstIndex(of: weightStep) ?? 0
            let next = options[(idx + 1) % options.count]
            Haptics.selection()
            setWeightStep(next)
        } label: {
            Text(label)
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
        .accessibilityValue(label)
        .accessibilityHint("Cycles through the available increments")
    }

    var rirBinding: Binding<Int> {
        Binding(
            get: { session.activeSet(for: exercise)?.repsInReserve ?? 2 },
            set: {
                session.updateActiveRIR(for: exercise, rir: $0)
                saveActiveSessionChanges()
            }
        )
    }
}

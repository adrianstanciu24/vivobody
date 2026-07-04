//
//  ActiveExerciseCardSections.swift
//  vivobody
//
//  Section view builders for ActiveExerciseCard, extracted from the
//  main file for readability: top meta, name + pips, hero (reps /
//  duration / completed), RIR, and the last-set caption + action
//  area. Members live on the ActiveExerciseCard extension and share
//  the struct's stored state.
//

import SwiftUI
import SwiftData

extension ActiveExerciseCard {
    // MARK: - Top meta

    var topMeta: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(setCountLabel)
                .panelLegend()
            Spacer()
        }
        .padding(.top, Space.xs)
    }

    var setCountLabel: String {
        if let active = activeIndex {
            return "Set \(active + 1) of \(sets.count)"
        }
        return "All sets complete"
    }

    // MARK: - Name + pips

    var nameRow: some View {
        Text(exercise.name)
            .font(Typography.display)
            .foregroundStyle(Ink.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    var setPips: some View {
        HStack(spacing: Space.md) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                let pipView = pip(isCompleted: set.isCompleted, isActive: idx == activeIndex)
                // Skip the menu on a lone pending set — there'd be
                // nothing to offer (can't remove the last set, nothing
                // logged to edit).
                if set.isCompleted {
                    pipView
                        .contextMenu { pipMenu(for: set) }
                        .accessibilityAction(named: "Edit set") { editingSet = set }
                        .accessibilityAction(named: "Delete set") { deletingSet = set }
                } else if sets.count > 1 {
                    pipView
                        .contextMenu { pipMenu(for: set) }
                        .accessibilityAction(named: "Remove set") { removeSet(set) }
                } else {
                    pipView
                }
            }
            addSetButton
        }
        .frame(height: 44)
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

    /// One-tap "add a set" — a quiet outlined plus that lives at the
    /// end of the pip row, where the count is already shown. Tapping
    /// it appends a set seeded from the current working set, so "one
    /// more" matches the weight you're already lifting. Adding a set
    /// to a finished exercise re-opens it for the new set.
    var addSetButton: some View {
        Button {
            addSet()
        } label: {
            Image(systemName: "plus")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Ink.quaternary, lineWidth: 2))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a set")
        .accessibilityInputLabels([Text("Add a set"), Text("Add Set"), Text("Add")])
    }

    /// Set pips as LED lamps: pending is unlit, the active set is
    /// armed (standby breathe), a completed set is lit — completing
    /// one overdrives the lamp past resting brightness before it
    /// settles with an afterglow, in the same frame as the crescendo.
    func pip(isCompleted: Bool, isActive: Bool) -> some View {
        LEDLamp(state: isCompleted ? .lit : (isActive ? .armed : .off))
    }

    // MARK: - Hero

    @ViewBuilder
    var heroBlock: some View {
        if session.activeSet(for: exercise) != nil {
            switch exercise.trackingMode {
            case .reps:     repsHero
            case .duration: durationHero
            }
        } else {
            completedHero
        }
    }

    /// Weight × reps instrument — the default lift.
    var repsHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BareScrubber(
                value: weightDisplayBinding,
                range: unit.strengthRange,
                step: unit.strengthStep,
                pointsPerStep: 8,
                fontSize: 104,
                unit: unit.symbol,
                unitFontSize: 18,
                numberColor: Ink.primary,
                unitColor: Ink.tertiary,
                accessibilityLabel: "Weight",
                showsScrubHint: isActive,
                performsScrubNudge: isActive,
                fitsWidth: true,
                tickTone: .deep,
                hitSlop: 12,
                showsRail: true
            )

            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("×")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: repsBinding,
                    range: 1...30,
                    step: 1,
                    pointsPerStep: 16,
                    fontSize: 46,
                    unit: "reps",
                    unitFontSize: 14,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: "Reps",
                    showsScrubHint: isActive,
                    hitSlop: 18
                )
            }
        }
    }

    /// Timed-hold instrument — the big number is the target duration
    /// (mm:ss); the optional load below handles weighted holds and
    /// loaded carries. Left at 0 the load simply reads as bodyweight.
    var durationHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BareScrubber(
                value: durationBinding,
                range: DurationFormatter.scrubRange,
                step: DurationFormatter.scrubStep,
                pointsPerStep: 10,
                fontSize: 104,
                numberColor: Ink.primary,
                formatter: { DurationFormatter.string($0) },
                accessibilityLabel: "Hold duration",
                showsScrubHint: isActive,
                performsScrubNudge: isActive,
                fitsWidth: true,
                hitSlop: 12,
                showsRail: true
            )

            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("+")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: weightDisplayBinding,
                    range: unit.strengthRange,
                    step: unit.strengthStep,
                    pointsPerStep: 8,
                    fontSize: 46,
                    unit: unit.symbol,
                    unitFontSize: 14,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: "Weight",
                    showsScrubHint: isActive,
                    tickTone: .deep,
                    hitSlop: 18
                )
            }
        }
    }

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

    func completedRepsHero(_ top: WorkoutSet?) -> some View {
        let weightText = top.map { WeightFormatter.string($0.weight, unit: unit, includeUnit: false) } ?? "—"
        let repsText = top.map { "\($0.reps)" } ?? "—"
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(weightText)
                    .font(Typography.bigMetric)
                    .foregroundStyle(Tint.complete)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit.symbol)
                    .font(Typography.metricInline)
                    .foregroundStyle(Tint.complete.opacity(Opacity.emphasis))
            }
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
        let loaded = (top?.weight ?? 0) > 0
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text(timeText)
                .font(Typography.bigMetric)
                .foregroundStyle(Tint.complete)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if loaded, let top {
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text("+")
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                    Text(WeightFormatter.string(top.weight, unit: unit, includeUnit: false))
                        .font(Typography.metricLg)
                        .foregroundStyle(Tint.complete.opacity(Opacity.strong))
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - RIR

    /// Reps-in-reserve pill — reps mode only (timed holds have no
    /// "reps left"). Panel discipline: when the exercise finishes the
    /// control goes dark but HOLDS ITS PLACE, like a hardware control
    /// whose lamp went out — the panel never reflows between states.
    @ViewBuilder
    var rirControl: some View {
        if exercise.trackingMode == .reps {
            let isLive = session.activeSet(for: exercise) != nil
            RIRSelector(value: rirBinding)
                .padding(.bottom, Space.md)
                .opacity(isLive ? 1 : 0)
                .allowsHitTesting(isLive)
                .accessibilityHidden(!isLive)
        }
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

    /// Echoes the previously-logged set's RIR in the "Last …" caption.
    /// Reps mode only — timed holds carry no reps-in-reserve.
    func lastSetRIRSuffix(_ set: WorkoutSet) -> String {
        guard exercise.trackingMode == .reps else { return "" }
        return "  ·  \(RIRSelector.displayLabel(set.repsInReserve)) RIR"
    }

    // MARK: - Last set + action

    @ViewBuilder
    var lastSetCaption: some View {
        if activeIndex != nil, sets.last(where: { $0.isCompleted }) == nil {
            // No set logged yet: reserve the caption's line so the
            // first completion lights the label without shoving the
            // action button down — fixed panel, arriving light.
            Text(" ")
                .font(Typography.metricUnit)
                .padding(.bottom, Space.sm)
                .accessibilityHidden(true)
        }
        if activeIndex != nil, let last = sets.last(where: { $0.isCompleted }) {
            Text("Last  \(exercise.setLabel(last, unit: unit))\(lastSetRIRSuffix(last))")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
                .padding(.bottom, Space.sm)
                .contextMenu {
                    Button {
                        editingSet = last
                    } label: {
                        Label("Edit last set", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingSet = last
                    } label: {
                        Label("Delete last set", systemImage: "trash")
                    }
                }
                .accessibilityAction(named: "Edit set") { editingSet = last }
                .accessibilityAction(named: "Delete set") { deletingSet = last }
        }
    }

    @ViewBuilder
    var actionArea: some View {
        if let active = session.activeSet(for: exercise) {
            let isLastSet = activeIndex == sets.count - 1
            let isHold = exercise.trackingMode == .duration
            SetCompleteButton(
                reps: active.reps,
                weight: active.weight,
                isComplete: pendingCompletionSetID == active.id,
                intensity: isLastSet ? .peak : .standard,
                title: completeTitle(isLastSet: isLastSet, isHold: isHold),
                accessibilityLabelOverride: isHold
                    ? "Hold \(DurationFormatter.string(active.duration))"
                    : nil,
                onToggle: { handleSetToggle(active) }
            )
            .accessibilityIdentifier("completeSetButton")
        } else {
            // Panel discipline: the completion line occupies exactly
            // the SetCompleteButton's 96pt slot, so finishing an
            // exercise changes what's lit — never where things sit.
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise complete")
                    .font(Typography.title)
                    .foregroundStyle(Tint.complete)
                Spacer()
                Text("Swipe for next  →")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }
            .frame(minHeight: 96)
        }
    }
}

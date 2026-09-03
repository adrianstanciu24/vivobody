//
//  ActiveRepsInstrument.swift
//  vivobody
//
//  Repetition-based active and completed instrument leaves. Resistance
//  semantics arrive as immutable input; model writes and scrub persistence
//  remain in bindings and actions supplied by ActiveExerciseCard.
//

import SwiftUI
import VivoKit

struct ActiveRepsInstrument: View {
    let input: ActiveRepsInstrumentInput
    @Binding var weight: Double
    @Binding var reps: Double
    let onScrubEnded: () -> Void
    let adjustResistance: (AccessibilityAdjustmentDirection) -> Void

    var body: some View {
        switch input.phase {
        case .active:
            activeInstrument
        case let .completed(completed):
            completedInstrument(completed)
        }
    }

    @ViewBuilder
    private var activeInstrument: some View {
        switch input.instrument.resistanceStyle {
        case .unloaded:
            unloadedInstrument
        case .bodyweightAdded:
            bodyweightInstrument
        case .enteredLoad:
            enteredLoadInstrument
        }
    }

    private var enteredLoadInstrument: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if input.instrument.loadMode == .assistanceSubtracted
                || input.instrument.loadMode == .nonComparable
            {
                Text(input.instrument.loadInputLabel)
                    .panelLegend()
            }
            resistanceAccessibleLoadControl {
                BareScrubber(
                    value: $weight,
                    range: input.instrument.unit.strengthRange,
                    step: input.instrument.weightStep,
                    pointsPerStep: 8,
                    fontSize: input.instrument.loadMode == .nonComparable ? 80 : 104,
                    unit: input.instrument.loadUnit(for: weight),
                    unitFontSize: 18,
                    numberColor: Ink.primary,
                    unitColor: Ink.tertiary,
                    formatter: activeLoadFormatter,
                    accessibilityLabel: input.instrument.loadInputLabel,
                    showsScrubHint: input.instrument.isActivePage,
                    performsScrubNudge: input.instrument.isActivePage,
                    fitsWidth: true,
                    tickTone: .deep,
                    hitSlop: 12,
                    showsRail: true,
                    cancellationID: input.instrument.scrubCancellationID,
                    onScrubEnded: onScrubEnded
                )
            }
            assistanceDirectionHint

            repsRow
        }
    }

    private var bodyweightInstrument: some View {
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
                    value: $weight,
                    range: input.instrument.unit.strengthRange,
                    step: input.instrument.weightStep,
                    pointsPerStep: 8,
                    fontSize: 40,
                    unit: input.instrument.unit.symbol,
                    unitFontSize: 13,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: input.instrument.loadInputLabel,
                    showsScrubHint: input.instrument.isActivePage,
                    performsScrubNudge: input.instrument.isActivePage,
                    tickTone: .deep,
                    hitSlop: 18,
                    cancellationID: input.instrument.scrubCancellationID,
                    onScrubEnded: onScrubEnded
                )
            }

            repsRow
        }
    }

    private var unloadedInstrument: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("REPS")
                .panelLegend()
                .accessibilityHidden(true)
            BareScrubber(
                value: $reps,
                range: 1 ... 30,
                step: 1,
                pointsPerStep: 16,
                fontSize: 104,
                unit: "reps",
                unitFontSize: 18,
                numberColor: Ink.primary,
                unitColor: Ink.tertiary,
                accessibilityLabel: "Reps",
                showsScrubHint: input.instrument.isActivePage,
                performsScrubNudge: input.instrument.isActivePage,
                fitsWidth: true,
                hitSlop: 12,
                showsRail: true,
                cancellationID: input.instrument.scrubCancellationID,
                onScrubEnded: onScrubEnded
            )
        }
    }

    private var repsRow: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Text("×")
                .font(Typography.statValue)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
            BareScrubber(
                value: $reps,
                range: 1 ... 30,
                step: 1,
                pointsPerStep: 16,
                fontSize: 46,
                unit: "reps",
                unitFontSize: 14,
                numberColor: Ink.primary.opacity(Opacity.strong),
                unitColor: Ink.tertiary,
                accessibilityLabel: "Reps",
                showsScrubHint: input.instrument.isActivePage,
                hitSlop: 18,
                showsRail: true,
                railClearance: 26,
                cancellationID: input.instrument.scrubCancellationID,
                onScrubEnded: onScrubEnded
            )
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func completedInstrument(_ completed: ActiveCompletedRepsInput) -> some View {
        if completed.isUnloaded {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("REPS")
                    .panelLegend()
                    .accessibilityHidden(true)
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text(completed.repsText)
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
            .accessibilityLabel("\(completed.repsText) reps")
        } else {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(completed.weightText)
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
                    Text(completed.repsText)
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
    }

    @ViewBuilder
    private func resistanceAccessibleLoadControl(
        @ViewBuilder content: () -> some View
    ) -> some View {
        if input.instrument.loadMode == .nonComparable {
            content()
                .accessibilityRepresentation {
                    Text("Resistance")
                        .accessibilityValue(
                            input.instrument.resistanceAccessibilityValue(
                                for: weight
                            )
                        )
                        .accessibilityHint("Swipe up or down to change")
                        .accessibilityAdjustableAction(adjustResistance)
                }
        } else {
            content()
        }
    }

    @ViewBuilder
    private var assistanceDirectionHint: some View {
        if input.instrument.showsAssistanceDirection {
            Text("Less assistance = harder")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("assistanceDirectionHint")
        }
    }

    private var activeLoadFormatter: ((Double) -> String)? {
        guard input.instrument.loadMode == .nonComparable else { return nil }
        return { input.instrument.loadText(for: $0) ?? "" }
    }
}

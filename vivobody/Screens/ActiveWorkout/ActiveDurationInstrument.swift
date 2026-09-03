//
//  ActiveDurationInstrument.swift
//  vivobody
//
//  Duration-based active and completed instrument leaves. Time remains the
//  hero while immutable resistance input determines the optional load row.
//

import SwiftUI
import VivoKit

struct ActiveDurationInstrument: View {
    let input: ActiveDurationInstrumentInput
    @Binding var weight: Double
    @Binding var duration: Double
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

    private var activeInstrument: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(input.instrument.modality.durationLabel)
                .panelLegend()
            BareScrubber(
                value: $duration,
                range: DurationFormatter.scrubRange,
                step: DurationFormatter.scrubStep,
                pointsPerStep: 10,
                fontSize: 104,
                numberColor: Ink.primary,
                formatter: { DurationFormatter.string($0) },
                accessibilityLabel: input.instrument.modality.durationLabel,
                showsScrubHint: input.instrument.isActivePage,
                performsScrubNudge: input.instrument.isActivePage,
                fitsWidth: true,
                hitSlop: 12,
                showsRail: true,
                cancellationID: input.instrument.scrubCancellationID,
                onScrubEnded: onScrubEnded
            )

            loadControl
        }
    }

    @ViewBuilder
    private var loadControl: some View {
        switch input.instrument.resistanceStyle {
        case .unloaded:
            EmptyView()
        case .bodyweightAdded:
            bodyweightLoadControl
        case .enteredLoad:
            enteredLoadControl
        }
    }

    private var bodyweightLoadControl: some View {
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
                    value: $weight,
                    range: input.instrument.unit.strengthRange,
                    step: input.instrument.weightStep,
                    pointsPerStep: 8,
                    fontSize: 32,
                    unit: input.instrument.unit.symbol,
                    unitFontSize: 13,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: input.instrument.loadInputLabel,
                    showsScrubHint: input.instrument.isActivePage,
                    tickTone: .deep,
                    hitSlop: 18,
                    cancellationID: input.instrument.scrubCancellationID,
                    onScrubEnded: onScrubEnded
                )
            }
        }
    }

    private var enteredLoadControl: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if input.instrument.loadMode == .assistanceSubtracted
                || input.instrument.loadMode == .nonComparable
            {
                Text(input.instrument.loadInputLabel)
                    .panelLegend()
            }
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                if input.instrument.loadMode != .nonComparable {
                    Text(input.instrument.loadMode.inputOperatorSymbol)
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                }
                resistanceAccessibleLoadControl {
                    BareScrubber(
                        value: $weight,
                        range: input.instrument.unit.strengthRange,
                        step: input.instrument.weightStep,
                        pointsPerStep: 8,
                        fontSize: 46,
                        unit: input.instrument.loadUnit(for: weight),
                        unitFontSize: 14,
                        numberColor: Ink.secondary,
                        unitColor: Ink.tertiary,
                        formatter: activeLoadFormatter,
                        accessibilityLabel: input.instrument.loadInputLabel,
                        showsScrubHint: input.instrument.isActivePage,
                        tickTone: .deep,
                        hitSlop: 18,
                        cancellationID: input.instrument.scrubCancellationID,
                        onScrubEnded: onScrubEnded
                    )
                }
            }
            assistanceDirectionHint
        }
    }

    private func completedInstrument(_ completed: ActiveCompletedDurationInput) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(completed.durationLabel)
                .panelLegend()
            Text(completed.timeText)
                .font(.system(size: 104, weight: .bold))
                .foregroundStyle(Tint.complete)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let loadText = completed.loadText {
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text(loadText)
                        .font(Typography.metricLg)
                        .foregroundStyle(Tint.complete.opacity(Opacity.strong))
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(completed.accessibilityLabel)
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

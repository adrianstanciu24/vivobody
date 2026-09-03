//
//  CustomExerciseLoggingDefaultsSection.swift
//  vivobody
//
//  Logging-default section for custom exercises plus the defaults-only row
//  shared by restricted bundled edits. Weight edits remain a UI-boundary
//  conversion while the draft stores canonical pounds.
//

import SwiftUI
import VivoKit

struct CustomExerciseLoggingDefaultsSection: View {
    @Binding var draft: CatalogDraft
    let validation: CatalogDraftValidation
    let showsValidationErrors: Bool
    let unit: WeightUnit
    let onPresentPicker: (CatalogPicker) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Logging defaults")

            loadModeField
                .id(CatalogDraftValidation.Anchor.loadMode)

            if draft.loadMode == .bodyweightAdded
                || draft.loadMode == .assistanceSubtracted
            {
                bodyweightFractionField
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if draft.showsLoggingDefaults {
                CustomExerciseDefaultsRow(draft: $draft, unit: unit)
            }
        }
    }

    private var loadModeField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            CustomExercisePickerRow(
                title: "Load interpretation",
                value: draft.loadMode.customExerciseChoiceName
            ) {
                onPresentPicker(.loadMode)
            }

            if showsValidationErrors, !validation.hasValidLoadProfile {
                CustomExerciseValidationMessage(
                    message: "Choose a load interpretation that matches this equipment."
                )
            }
        }
    }

    private var bodyweightFractionField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            CustomExerciseValueColumn(label: "Bodyweight carried") {
                BareScrubber(
                    value: $draft.bodyweightFraction,
                    range: 0 ... 1,
                    step: 0.05,
                    pointsPerStep: 14,
                    fontSize: 40,
                    numberColor: Ink.primary,
                    formatter: { value in
                        "\(Int((value * 100).rounded()))%"
                    },
                    accessibilityLabel: "Bodyweight carried"
                )
            }
            if showsValidationErrors, draft.bodyweightFraction == 0 {
                CustomExerciseValidationMessage(
                    message: "Bodyweight load modes require a carried fraction above zero."
                )
            }
        }
    }
}

struct CustomExerciseDefaultsRow: View {
    @Binding var draft: CatalogDraft
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if draft.trackingMode == .duration || draft.tracksResistance {
                Text("Defaults")
                    .sectionLabelStyle(Opacity.medium)

                HStack(alignment: .top, spacing: Space.xxl) {
                    switch draft.trackingMode {
                    case .reps:
                        CustomExerciseValueColumn(label: draft.loadMode.inputLabel) {
                            BareScrubber(
                                value: defaultWeightBinding,
                                range: unit.strengthRange,
                                step: unit.strengthStep,
                                pointsPerStep: 8,
                                fontSize: 40,
                                unit: unit.symbol,
                                unitFontSize: 13,
                                numberColor: Ink.primary,
                                unitColor: Ink.tertiary,
                                accessibilityLabel: draft.loadMode.inputLabel,
                                tickTone: .deep
                            )
                        }
                    case .duration:
                        CustomExerciseValueColumn(label: draft.modality.durationLabel) {
                            BareScrubber(
                                value: defaultDurationBinding,
                                range: DurationFormatter.scrubRange,
                                step: DurationFormatter.scrubStep,
                                pointsPerStep: 10,
                                fontSize: 40,
                                numberColor: Ink.primary,
                                formatter: { DurationFormatter.string($0) },
                                accessibilityLabel: draft.modality.durationLabel
                            )
                        }
                        if draft.tracksResistance {
                            CustomExerciseValueColumn(label: draft.loadMode.inputLabel) {
                                BareScrubber(
                                    value: defaultWeightBinding,
                                    range: unit.strengthRange,
                                    step: unit.strengthStep,
                                    pointsPerStep: 8,
                                    fontSize: 40,
                                    unit: unit.symbol,
                                    unitFontSize: 13,
                                    numberColor: Ink.primary,
                                    unitColor: Ink.tertiary,
                                    accessibilityLabel: draft.loadMode.inputLabel,
                                    tickTone: .deep
                                )
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Scrubbed in display units; stored canonical (lb) on the draft.
    private var defaultWeightBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(draft.defaultWeight, unit: unit) },
            set: { draft.defaultWeight = WeightFormatter.toCanonical($0, unit: unit) }
        )
    }

    private var defaultDurationBinding: Binding<Double> {
        Binding(
            get: { draft.defaultDuration },
            set: { draft.defaultDuration = $0 }
        )
    }
}

private struct CustomExerciseValueColumn<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
            content()
        }
    }
}

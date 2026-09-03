//
//  ExerciseDetailPerformanceSection.swift
//  vivobody
//
//  Stateless effective-load explanation and tested one-rep-max action for
//  Exercise Detail. Archive-derived load copy arrives from the read model;
//  editing remains an explicit action owned by the root screen.
//

import SwiftUI
import VivoKit

struct ExerciseDetailPerformanceSection: View {
    let effectiveLoad: ExerciseDetailReadModel.EffectiveLoad?
    let measuredOneRepMax: Double?
    let supportsEstimatedOneRepMax: Bool
    let unit: WeightUnit
    let onEditOneRepMax: () -> Void

    var body: some View {
        VStack(spacing: Space.sm) {
            if let effectiveLoad {
                effectiveLoadRow(effectiveLoad)
            }
            if supportsEstimatedOneRepMax {
                oneRepMaxRow
            }
        }
    }

    /// The standing record's absolute resistance beside the exact
    /// bodyweight snapshot, movement coefficient, and logged resistance
    /// that produced it.
    private func effectiveLoadRow(
        _ effectiveLoad: ExerciseDetailReadModel.EffectiveLoad
    ) -> some View {
        KitRow(
            title: "Effective load",
            subtitle: effectiveLoad.explanationText
        ) {
            Text(effectiveLoad.valueText)
                .font(Typography.statValue)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(effectiveLoad.accessibilityLabel)
    }

    /// Dedicated, tappable tested-1RM row. Estimated strength remains
    /// owned by the trend card, so this action is an explicit measurement.
    private var oneRepMaxRow: some View {
        Button {
            Haptics.soft()
            onEditOneRepMax()
        } label: {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1RM")
                        .sectionLabelStyle(Opacity.soft)
                    Text(measuredOneRepMax == nil ? "Tap to enter your tested max" : "Tested")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }

                Spacer(minLength: Space.sm)

                if let measuredOneRepMax {
                    Text(WeightFormatter.string(measuredOneRepMax, unit: unit))
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                } else {
                    Text("Add")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Tint.complete)
                }

                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity)
            .contentCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("One-rep max")
    }
}

#if DEBUG
    #Preview("Exercise performance") {
        VStack(spacing: Space.sm) {
            ExerciseDetailPerformanceSection(
                effectiveLoad: ExerciseDetailReadModel.EffectiveLoad(
                    value: 205,
                    valueText: "205 lb",
                    formulaText: "180 lb BW × 100% + 25 lb",
                    explanationText: "180 lb BW × 100% + 25 lb",
                    accessibilityLabel: "Effective load, 205 lb. 180 lb body weight at 100 percent plus 25 lb"
                ),
                measuredOneRepMax: 225,
                supportsEstimatedOneRepMax: true,
                unit: .lb,
                onEditOneRepMax: {}
            )
        }
        .padding(Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
#endif

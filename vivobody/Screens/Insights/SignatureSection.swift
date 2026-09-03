//
//  SignatureSection.swift
//  vivobody
//
//  Composes the Insights training-shape hero from its section heading,
//  adaptive visual instrument, identity, summary stats, and even-share key.
//  The emblem's motion host and Canvas renderers live in focused files so
//  this section owns hierarchy without also owning frame scheduling or paint.
//

import SwiftUI
import VivoKit

struct SignatureSection: View {
    let signature: TrainingSignature

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            SectionHeader(
                title: "Training shape",
                trailing: signature.hasSignature ? "all time" : "first signal",
                trailingIsInProgress: !signature.hasSignature,
                accessibilityIdentifier: "insightsShapeInstrument"
            )

            if dynamicTypeSize.isAccessibilitySize {
                SignatureAccessibilitySpectrum(signature: signature)
            } else {
                SignatureMotionHost(signature: signature)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.sm)
            }

            if !signature.hasSignature {
                Text("waiting for the first muscle-mapped set")
                    .panelLegend()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Space.sm)
            } else {
                Text(focusLabel)
                    .font(Typography.display)
                    .foregroundStyle(Tint.primaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                StatStrip(
                    stats: [
                        Stat(
                            value: signature.hasVolume
                                ? "\(Int((signature.balance * 100).rounded()))"
                                : "—",
                            unit: signature.hasVolume ? "%" : nil,
                            label: "Evenness"
                        ),
                        Stat(
                            value: "\(signature.trainedGroupCount)/6",
                            label: "Regions trained"
                        ),
                    ],
                    valueFont: Typography.statValue
                )
                .padding(.vertical, Space.xs)

                HStack(spacing: Space.sm) {
                    Capsule(style: .continuous)
                        .stroke(
                            Ink.primary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                        .frame(width: 28, height: 8)
                        .accessibilityHidden(true)
                    Text("dashed = even six-way share")
                        .panelLegend()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dashed petals show an even six-way share")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusLabel: String {
        guard signature.hasSignature else { return "Awaiting history" }
        if let group = signature.dominantGroup {
            return "\(group.displayName)-led"
        }
        if signature.trainedGroupCount == MuscleGroup.allCases.count,
           signature.balance >= TrainingSignature.evenBalanceThreshold
        {
            return "Evenly spread"
        }
        return "No single lead"
    }
}

//
//  TrainingLoadVolumeDecoder.swift
//  vivobody
//
//  Explains the volume-load measure inside Today's Training Load decoder.
//  It keeps the selected-measure teaching visual and compact while the
//  enclosing sheet owns the user's rolling receipt and personal comparison.
//

import SwiftUI
import VivoKit

struct TrainingLoadVolumeDecoder: View {
    let report: TrainingLoadReport
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text("02")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Tint.primary)
                    .monospacedDigit()
                Text("Weigh the work")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Space.lg) {
                signalChain

                Text("Each comparable set multiplies its effective load by completed reps. The app totals those values in \(unit.symbol); effort does not discount this measure.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                StatStrip(
                    stats: [
                        Stat(
                            value: format(report.drivers.hardSets.current),
                            label: "Hard sets"
                        ),
                        Stat(
                            value: "\(Int(report.drivers.sessions.current.rounded()))",
                            label: "Sessions"
                        ),
                    ],
                    valueFont: Typography.metricInline
                )

                Text("Hard sets remain a driver of the week. Bands, timed holds, and sets missing a required load stay outside this total.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.xl)
            .contentCard()
        }
    }

    private var signalChain: some View {
        VStack(spacing: Space.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.xs) {
                    signalChip("Effective load")
                    multiplicationSign
                    signalChip("Completed reps")
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(spacing: Space.xs) {
                    signalChip("Effective load")
                    multiplicationSign
                    signalChip("Completed reps")
                }
            }

            HStack(spacing: Space.sm) {
                Rectangle()
                    .fill(Surface.edge)
                    .frame(height: 1)
                Circle()
                    .fill(Tint.primary)
                    .frame(width: 9, height: 9)
                    .shadow(color: Tint.primary.opacity(0.45), radius: 5)
                Text("Volume load")
                    .panelLegend()
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume load multiplies effective load by completed reps")
    }

    private var multiplicationSign: some View {
        Text("×")
            .foregroundStyle(Ink.quaternary)
            .accessibilityHidden(true)
    }

    private func signalChip(_ label: String) -> some View {
        Text(label)
            .panelLegend()
            .padding(.horizontal, Space.sm)
            .frame(minHeight: 32)
            .background(Surface.cardTintBright, in: Capsule())
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

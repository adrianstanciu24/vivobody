//
//  InsightsEmptyDetail.swift
//  vivobody
//
//  The trailing lane of an empty Insights on a wide window. With nothing to
//  read yet, it shows the shape of the instruments as a redacted outline, so
//  the lane says what Insights will hold without inventing numbers.
//

import SwiftUI
import VivoKit

struct InsightsEmptyDetail: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                intro
                sampleReadout
            }
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Your first readout")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Text("Each logged workout adds to your training shape, load, rhythm, and balance here.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The signature, load, and rhythm instruments, redacted. The strings
    /// only size the placeholder bars; none of them is shown.
    private var sampleReadout: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            sampleCard(legend: "Last 4 weeks", title: "Training signature") {
                HStack(alignment: .bottom, spacing: Space.sm) {
                    ForEach(Array([0.55, 0.9, 0.4, 0.7, 0.3, 0.6].enumerated()), id: \.offset) { _, fraction in
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72 * fraction)
                    }
                }
                .frame(height: 72, alignment: .bottom)
            }

            sampleCard(legend: "Last 7 days", title: "Training load") {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("8,420 lb")
                        .font(Typography.metricLg)
                    StatStrip(
                        stats: [
                            Stat(value: "3", label: "Sessions"),
                            Stat(value: "12", label: "1–5 reps"),
                            Stat(value: "24", label: "6–12 reps"),
                        ],
                        edgeAligned: true
                    )
                }
            }

            sampleCard(legend: "Last 2 weeks", title: "Rhythm") {
                HStack(spacing: Space.xs) {
                    ForEach(0 ..< 14, id: \.self) { _ in
                        Circle()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .foregroundStyle(Ink.primary)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample insights readout")
        .accessibilityIdentifier("insightsSampleReadout")
    }

    private func sampleCard(
        legend: String,
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(legend)
                    .panelLegendType()
                Text(title)
                    .font(Typography.headline)
            }
            content()
                // Redaction leaves shapes untouched, so the shapes are dimmed
                // to read as placeholders beside the redacted text.
                .opacity(0.16)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }
}

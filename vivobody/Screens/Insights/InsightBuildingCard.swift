//
//  InsightBuildingCard.swift
//  vivobody
//
//  Shared qualification state for Insights instruments that are still
//  collecting enough evidence to make their read. A breathing signal
//  lamp makes the state visible during a fast scroll; the segmented rail
//  moves only when real workout evidence advances. This is deliberately
//  not a loading spinner — nothing progresses until the user trains.
//

import SwiftUI
import VivoKit

struct InsightBuildingCard: View {
    let title: String
    let detail: String
    var progress: Double? = nil
    var progressLabel: String? = nil
    var accessibilityProgress: String? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            signalHeading

            if let progress {
                VStack(alignment: .leading, spacing: Space.sm) {
                    progressHeading

                    SegmentLadder(
                        fraction: progress,
                        segments: 24,
                        tint: Tint.inProgress,
                        height: 6,
                        spacing: 3
                    )
                }
            }

            Text(detail)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tint.inProgress.opacity(0.10),
                            Tint.inProgress.opacity(0.02),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 92
                    )
                )
                .frame(width: 184, height: 184)
                .offset(x: 56, y: -68)
                .accessibilityHidden(true)
        }
        .contentCard(tint: Tint.inProgress.opacity(0.055), bright: true)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var signalHeading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.md) {
                InsightSignalBeacon()
                headingCopy
            }
        } else {
            HStack(alignment: .center, spacing: Space.lg) {
                InsightSignalBeacon()
                headingCopy
            }
        }
    }

    private var headingCopy: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Signal building")
                .panelLegendType()
                .foregroundStyle(Tint.inProgress)

            Text(title)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var progressHeading: some View {
        if let progressLabel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text("Evidence")
                        .panelLegend()
                    Spacer(minLength: Space.sm)
                    Text(progressLabel)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Evidence")
                        .panelLegend()
                    Text(progressLabel)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var accessibilityLabel: String {
        [
            "Signal building. \(title).",
            accessibilityProgress ?? progressLabel,
            detail,
        ]
        .compactMap(\.self)
        .joined(separator: " ")
    }
}

/// A physical standby lamp with a quiet radar-like field around it.
/// Only the lamp breathes; the surrounding geometry remains fixed so
/// animation never masquerades as changing progress.
private struct InsightSignalBeacon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tint.inProgress.opacity(0.24),
                            Tint.inProgress.opacity(0.07),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 33
                    )
                )

            Circle()
                .stroke(Tint.inProgress.opacity(0.20), lineWidth: 1)
                .frame(width: 54, height: 54)

            Circle()
                .stroke(
                    Ink.primary.opacity(0.15),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                )
                .frame(width: 40, height: 40)

            LEDLamp(state: .armed, size: 16)
        }
        .frame(width: 66, height: 66)
        .accessibilityHidden(true)
    }
}

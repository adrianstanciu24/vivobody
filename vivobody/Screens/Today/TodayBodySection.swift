//
//  TodayBodySection.swift
//  vivobody
//
//  Today's trained-body hero and its compact development legend. The section
//  receives rendered development input and one details action; it owns no
//  analytics lookup or presentation state.
//

import SwiftUI
import VivoKit

struct TodayBodySection: View {
    let height: CGFloat
    let state: MuscleDevelopment.State
    let warmth: Double
    let colorScheme: ColorScheme
    let usesAccessibilityLayout: Bool
    let onShowDetails: () -> Void

    var body: some View {
        VStack(spacing: Space.section) {
            StagedBodyModel(
                renderHeight: height,
                channels: state.nodeChannels,
                warmth: warmth
            )
            .padding(.horizontal, -Space.gutter)
            .accessibilityElement()
            .accessibilityLabel("Current training development body model")
            .accessibilityValue("Muscle colour reflects your recent training development")
            .accessibilityHint("Opens a text summary for each muscle group")
            .accessibilityAction {
                onShowDetails()
            }
            .accessibilityAction(named: "Show muscle details") {
                onShowDetails()
            }

            developmentLegend
        }
    }

    private var developmentLegend: some View {
        Button(action: onShowDetails) {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Text("Training development")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
                developmentScale
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md)
            .contentChip()
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Current training development legend. No history, low, building, consistent, and high"
        )
        .accessibilityHint("Opens muscle details")
    }

    /// The neutral no-history swatch shares the ramp's shape but sits
    /// apart from it: a separate state, not the bottom of the scale.
    private var developmentScale: some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(spacing: Space.xs) {
                Capsule()
                    .fill(color(for: .noData))
                    .frame(width: noHistorySwatchWidth, height: legendBarHeight)
                Text(MuscleDevelopmentBand.noData.displayName)
                    .lineLimit(1)
            }
            .fixedSize()

            VStack(spacing: Space.xs) {
                developmentRamp
                rampLabels
            }
        }
        .font(Typography.micro)
        .foregroundStyle(Ink.tertiary)
    }

    /// One continuous sweep of the actual render ramp, with hairline
    /// ticks at the band boundaries the labels describe.
    private var developmentRamp: some View {
        Capsule()
            .fill(rampGradient)
            .frame(height: legendBarHeight)
            .overlay {
                HStack(spacing: 0) {
                    ForEach(trainedBands.indices, id: \.self) { index in
                        Color.clear
                        if index < trainedBands.count - 1 {
                            Rectangle()
                                .fill(Surface.background.opacity(0.7))
                                .frame(width: 1)
                        }
                    }
                }
            }
            .overlay {
                Capsule().strokeBorder(Surface.edge, lineWidth: 0.5)
            }
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var rampLabels: some View {
        if usesAccessibilityLayout {
            HStack {
                Text(MuscleDevelopmentBand.low.displayName)
                Spacer(minLength: Space.md)
                Text(MuscleDevelopmentBand.high.displayName)
            }
        } else {
            HStack(spacing: 0) {
                ForEach(trainedBands, id: \.rawValue) { band in
                    Text(band.displayName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private let legendBarHeight: CGFloat = 10
    private let noHistorySwatchWidth: CGFloat = 28

    private var trainedBands: [MuscleDevelopmentBand] {
        MuscleDevelopmentBand.allCases.filter { $0 != .noData }
    }

    private var rampGradient: LinearGradient {
        let stops = stride(from: 0.0, through: 1.0, by: 0.125).map { intensity in
            Gradient.Stop(
                color: color(for: MuscleMapChannels(intensity: intensity)),
                location: intensity
            )
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }

    private func color(for channels: MuscleMapChannels) -> Color {
        let rgb = MuscleColor.rgb(
            for: channels,
            theme: colorScheme == .dark ? .dark : .light
        )
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

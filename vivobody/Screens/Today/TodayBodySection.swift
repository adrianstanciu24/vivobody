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
            VStack(spacing: Space.sm) {
                developmentLegendBands
                Text("Current training development · tap for details")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
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

    @ViewBuilder
    private var developmentLegendBands: some View {
        if usesAccessibilityLayout {
            VStack(spacing: Space.xs) {
                HStack(spacing: 4) {
                    legendBands
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("No history")
                    Spacer(minLength: Space.md)
                    Text("High")
                }
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)
            }
            .accessibilityHidden(true)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 54), spacing: Space.xs)],
                spacing: Space.sm
            ) {
                ForEach(MuscleDevelopmentBand.allCases, id: \.rawValue) { band in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(legendColor(for: band))
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        Text(band.displayName)
                            .font(Typography.micro)
                            .foregroundStyle(Ink.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var legendBands: some View {
        ForEach(MuscleDevelopmentBand.allCases, id: \.rawValue) { band in
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .fill(legendColor(for: band))
                .frame(maxWidth: .infinity)
                .frame(height: 8)
        }
    }

    private func legendColor(for band: MuscleDevelopmentBand) -> Color {
        let channels = band == .noData
            ? MuscleMapChannels.noData
            : MuscleMapChannels(intensity: band.representativeIntensity)
        let rgb = MuscleColor.rgb(
            for: channels,
            theme: colorScheme == .dark ? .dark : .light
        )
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

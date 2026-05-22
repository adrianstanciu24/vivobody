//
//  PlateVisualizerGallery.swift
//  workapp
//
//  Drag the scrubber, watch the plates arrange themselves on the bar.
//  This is the gallery composition that proves the components compose.
//

import SwiftUI

struct PlateVisualizerGallery: View {
    @State private var weight: Double = 135
    @State private var weightStep: Double = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text("INCREMENT")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))

                StepSelector(
                    selection: $weightStep,
                    options: [1.0, 2.5, 5.0]
                ) { value in
                    value.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(value)) lb"
                        : String(format: "%.1f lb", value)
                }
            }

            NumberScrubber(
                value: $weight,
                range: 0...600,
                step: weightStep,
                pointsPerStep: pointsPerStep(for: weightStep),
                unit: "lb",
                label: "weight"
            )

            Spacer().frame(height: 8)

            PlateVisualizer(weight: weight, barWeight: 45, unit: .lb)
                .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLATE VISUALIZER")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Load the bar.")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("Scrub the weight — plates slide on and off symmetrically. Real colors, real sizes, real plate math.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pointsPerStep(for step: Double) -> CGFloat {
        switch step {
        case 1: return 6
        case 2.5: return 10
        default: return 12
        }
    }
}

#Preview("Plate Visualizer") {
    PlateVisualizerGallery()
        .preferredColorScheme(.dark)
}

#Preview("Plate Visualizer — kg") {
    VStack(spacing: 40) {
        PlateVisualizer(weight: 20, barWeight: 20, unit: .kg)
        PlateVisualizer(weight: 60, barWeight: 20, unit: .kg)
        PlateVisualizer(weight: 100, barWeight: 20, unit: .kg)
        PlateVisualizer(weight: 142.5, barWeight: 20, unit: .kg)
        PlateVisualizer(weight: 180, barWeight: 20, unit: .kg)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}

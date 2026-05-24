//
//  NumberScrubberGallery.swift
//  vivobody
//
//  Interactive preview for NumberScrubber + StepSelector.
//  Pick an increment (1 / 2.5 / 5 lb), then drag the weight scrubber.
//  Same physical drag distance ≈ same weight change, regardless of step.
//

import SwiftUI

struct NumberScrubberGallery: View {
    @State private var weight: Double = 135
    @State private var reps: Double = 8
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
                range: 0...500,
                step: weightStep,
                pointsPerStep: pointsPerStep(for: weightStep),
                unit: "lb",
                label: "weight"
            )

            NumberScrubber(
                value: $reps,
                range: 0...30,
                step: 1,
                pointsPerStep: 14,
                unit: "reps",
                label: "reps"
            )

            Spacer()

            readout
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NUMBER SCRUBBER")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Drag to dial.")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("Up to increase, down to decrease. Each step ticks. Pull past the limit to feel the wall.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readout: some View {
        HStack(spacing: 6) {
            DigitTicker(
                value: weight,
                font: .system(size: 18, weight: .semibold, design: .rounded),
                color: .white,
                fractionalDigits: weightStep.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
            )
            Text("lb")
                .foregroundStyle(.white.opacity(0.4))
            Text("×")
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 4)
            DigitTicker(
                value: reps,
                font: .system(size: 18, weight: .semibold, design: .rounded),
                color: .white
            )
            Text("reps")
                .foregroundStyle(.white.opacity(0.4))
        }
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    // MARK: - Helpers

    /// Larger drag distance per tick when the step itself is small,
    /// so a 10 lb change covers a similar finger swipe at any step.
    private func pointsPerStep(for step: Double) -> CGFloat {
        switch step {
        case 1: return 6
        case 2.5: return 10
        default: return 12
        }
    }

}

#Preview("Number Scrubber") {
    NumberScrubberGallery()
        .preferredColorScheme(.dark)
}

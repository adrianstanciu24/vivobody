//
//  ScrubberCardGallery.swift
//  vivobody
//
//  Interactive liquid-card scrubbers inside a scrolling surface.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct ScrubberCardGallery: View {
        @State private var weight: Double = 135
        @State private var reps: Double = 8
        @State private var weightStep: Double = 5

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header

                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("INCREMENT")
                            .font(Typography.metricMicro)
                            .tracking(2)
                            .foregroundStyle(Ink.tertiary)

                        StepSelector(
                            selection: $weightStep,
                            options: [1.0, 2.5, 5.0]
                        ) { value in
                            value.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(value)) lb"
                                : String(format: "%.1f lb", value)
                        }
                    }

                    BareScrubber(
                        value: $weight,
                        range: 0 ... 500,
                        step: weightStep,
                        pointsPerStep: pointsPerStep(for: weightStep),
                        fontSize: 64,
                        unit: "lb",
                        tickTone: .deep,
                        presentation: .card,
                        cardLabel: "Weight"
                    )

                    BareScrubber(
                        value: $reps,
                        range: 0 ... 30,
                        step: 1,
                        pointsPerStep: 14,
                        fontSize: 64,
                        unit: "reps",
                        presentation: .card,
                        cardLabel: "Reps"
                    )

                    readout
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.section)
                .padding(.bottom, Space.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Surface.background.ignoresSafeArea())
            .onAppear { Haptics.prepare() }
        }

        // MARK: - Pieces

        private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("CARD SCRUBBER")
                    .font(Typography.metricMicro)
                    .tracking(2)
                    .foregroundStyle(Ink.tertiary)
                Text("Drag to dial.")
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                Text("Up to increase, down to decrease. Each step ticks. Pull past the limit to feel the wall.")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var readout: some View {
            HStack(spacing: Space.sm) {
                DigitTicker(
                    value: weight,
                    font: Typography.metricInline,
                    fractionalDigits: weightStep.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1,
                    rolls: false
                )
                Text("lb")
                    .foregroundStyle(Ink.tertiary)
                Text("×")
                    .foregroundStyle(Ink.quaternary)
                    .padding(.horizontal, 4)
                DigitTicker(
                    value: reps,
                    font: Typography.metricInline,
                    rolls: false
                )
                Text("reps")
                    .foregroundStyle(Ink.tertiary)
            }
            .font(Typography.metricInline)
            .foregroundStyle(Ink.primary)
            .padding(.vertical, Space.lg)
            .padding(.horizontal, Space.xl)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Ink.primary.opacity(0.05)))
        }

        // MARK: - Helpers

        /// Larger drag distance per tick when the step itself is small,
        /// so a 10 lb change covers a similar finger swipe at any step.
        private func pointsPerStep(for step: Double) -> CGFloat {
            switch step {
            case 1: 6
            case 2.5: 10
            default: 12
            }
        }
    }

    #Preview("Card Scrubber · Dark") {
        ScrubberCardGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Card Scrubber · Light") {
        ScrubberCardGallery()
            .preferredColorScheme(.light)
    }

#endif

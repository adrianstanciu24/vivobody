//
//  DigitTickerGallery.swift
//  vivobody
//
//  Native numeric transitions at multiple scales, with instant-swap mode.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct DigitTickerGallery: View {
        @State private var weight: Double = 135
        @State private var reps: Double = 8
        @State private var pr: Double = 225
        @State private var fine: Double = 2.5
        @State private var rolls = true

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header

                    Toggle("Animate value changes", isOn: $rolls)
                        .frame(minHeight: 44)

                    section(
                        label: "WEIGHT  ·  scrubber readout",
                        unit: "lb",
                        value: $weight,
                        step: 5,
                        range: 0 ... 995,
                        font: Typography.metricHero
                    )

                    section(
                        label: "REPS  ·  small",
                        unit: nil,
                        value: $reps,
                        step: 1,
                        range: 1 ... 30,
                        font: Typography.statValue
                    )

                    section(
                        label: "PR  ·  hero",
                        unit: "lb",
                        value: $pr,
                        step: 5,
                        range: 100 ... 995,
                        font: Typography.bigMetric
                    )

                    section(
                        label: "FINE  ·  decimal",
                        unit: "lb",
                        value: $fine,
                        step: 1.25,
                        range: 0 ... 50,
                        fractionalDigits: 2,
                        font: Typography.metricLg
                    )

                    Spacer().frame(height: 6)
                    scrambleButton
                    Spacer().frame(height: 12)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.section)
                .padding(.bottom, Space.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Surface.background.ignoresSafeArea())
            .onAppear { Haptics.prepare() }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("DIGIT TICKER")
                    .font(Typography.metricMicro)
                    .tracking(2)
                    .foregroundStyle(Ink.tertiary)
                Text("Native number motion.")
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                Text("Compare numeric transitions with instant swaps. Reduce Motion disables the animation.")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .padding(.top, 2)
            }
        }

        private func section(
            label: String,
            unit: String?,
            value: Binding<Double>,
            step: Double,
            range: ClosedRange<Double>,
            fractionalDigits: Int = 0,
            font: Font
        ) -> some View {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text(label.uppercased())
                    .font(Typography.metricMicro)
                    .tracking(2)
                    .foregroundStyle(Ink.tertiary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    DigitTicker(
                        value: value.wrappedValue,
                        font: font,
                        fractionalDigits: fractionalDigits,
                        rolls: rolls
                    )
                    if let unit {
                        Text(unit)
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.tertiary)
                    }
                    Spacer()
                    stepper(value: value, step: step, range: range)
                }
            }
            .padding(Space.xl)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(Ink.primary.opacity(0.04))
            )
        }

        private func stepper(value: Binding<Double>, step: Double, range: ClosedRange<Double>) -> some View {
            HStack(spacing: Space.sm) {
                stepperButton(symbol: "minus") {
                    let new = max(range.lowerBound, value.wrappedValue - step)
                    if new != value.wrappedValue {
                        value.wrappedValue = new
                        Haptics.tick()
                    } else {
                        Haptics.rigid()
                    }
                }
                stepperButton(symbol: "plus") {
                    let new = min(range.upperBound, value.wrappedValue + step)
                    if new != value.wrappedValue {
                        value.wrappedValue = new
                        Haptics.tick()
                    } else {
                        Haptics.rigid()
                    }
                }
            }
        }

        private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.primary)
                    .frame(width: 44, height: 44)
                    .background(Ink.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }

        private var scrambleButton: some View {
            Button {
                Haptics.thunk()
                weight = Double(Int.random(in: 0 ... 19) * 5)
                reps = Double(Int.random(in: 1 ... 30))
                pr = Double(Int.random(in: 20 ... 199) * 5)
                fine = Double(Int.random(in: 0 ... 40)) * 1.25
            } label: {
                HStack {
                    Image(systemName: "dice")
                        .font(Typography.sectionLabel)
                    Text("SCRAMBLE")
                        .font(Typography.metricUnit)
                        .tracking(2)
                }
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(Ink.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .stroke(Ink.primary.opacity(0.10), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    #Preview("Digit Ticker") {
        DigitTickerGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Digit Ticker · Light") {
        DigitTickerGallery()
            .preferredColorScheme(.light)
    }

    #Preview("Solo · big") {
        @Previewable @State var value: Double = 195
        return VStack(spacing: Space.section) {
            DigitTicker(value: value, font: Typography.bigMetric)
            HStack(spacing: 12) {
                Button("−5") { value -= 5 }
                Button("+1") { value += 1 }
                Button("+5") { value += 5 }
                Button("+25") { value += 25 }
                Button("+100") { value += 100 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

#endif

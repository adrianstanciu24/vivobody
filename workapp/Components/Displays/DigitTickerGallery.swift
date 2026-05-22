//
//  DigitTickerGallery.swift
//  workapp
//
//  Four tickers at different scales (PR-hero, scrubber-readout,
//  metadata, fine). Each has +/- buttons; one SCRAMBLE button at the
//  bottom changes everything to random values at once so you can feel
//  big multi-digit cascades.
//

import SwiftUI

struct DigitTickerGallery: View {
    @State private var weight: Double = 135
    @State private var reps: Double = 8
    @State private var pr: Double = 225
    @State private var fine: Double = 2.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header

                section(
                    label: "WEIGHT  ·  scrubber readout",
                    unit: "lb",
                    value: $weight,
                    step: 5,
                    range: 0...995,
                    font: .system(size: 56, weight: .bold, design: .monospaced)
                )

                section(
                    label: "REPS  ·  small",
                    unit: nil,
                    value: $reps,
                    step: 1,
                    range: 1...30,
                    font: .system(size: 28, weight: .semibold, design: .monospaced)
                )

                section(
                    label: "PR  ·  hero",
                    unit: "lb",
                    value: $pr,
                    step: 5,
                    range: 100...995,
                    font: .system(size: 92, weight: .bold, design: .monospaced)
                )

                section(
                    label: "FINE  ·  decimal",
                    unit: "lb",
                    value: $fine,
                    step: 1.25,
                    range: 0...50,
                    fractionalDigits: 2,
                    font: .system(size: 36, weight: .bold, design: .monospaced)
                )

                Spacer().frame(height: 6)
                scrambleButton
                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DIGIT TICKER")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("Numbers roll, they don't fade.")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("Each digit moves independently. Only the digits that change animate. Direction follows the value.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
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
        VStack(alignment: .leading, spacing: 14) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.40))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                DigitTicker(
                    value: value.wrappedValue,
                    font: font,
                    fractionalDigits: fractionalDigits
                )
                if let unit {
                    Text(unit)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                stepper(value: value, step: step, range: range)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func stepper(value: Binding<Double>, step: Double, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 6) {
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var scrambleButton: some View {
        Button {
            Haptics.thunk()
            weight = Double(Int.random(in: 0...19) * 5)
            reps = Double(Int.random(in: 1...30))
            pr = Double(Int.random(in: 20...199) * 5)
            fine = Double(Int.random(in: 0...40)) * 1.25
        } label: {
            HStack {
                Image(systemName: "dice")
                    .font(.system(size: 13, weight: .bold))
                Text("SCRAMBLE")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(.white.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Digit Ticker") {
    DigitTickerGallery()
        .preferredColorScheme(.dark)
}

#Preview("Solo · big") {
    @Previewable @State var value: Double = 195
    return VStack(spacing: 30) {
        DigitTicker(value: value, font: .system(size: 120, weight: .bold, design: .monospaced))
        HStack(spacing: 12) {
            Button("−5") { value -= 5 }
            Button("+1") { value += 1 }
            Button("+5") { value += 5 }
            Button("+25") { value += 25 }
            Button("+100") { value += 100 }
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}

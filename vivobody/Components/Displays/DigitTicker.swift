//
//  DigitTicker.swift
//  vivobody
//
//  Native numeric Text with instant updates during scrubbing.
//

import SwiftUI
import VivoKit

struct DigitTicker: View {
    let value: Double
    var font: Font = Typography.metricLg
    var color: Color = Ink.primary
    var fractionalDigits: Int = 0
    var animation: Animation = .spring(response: 0.34, dampingFraction: 0.74)
    /// Scrubbers disable motion during both dragging and flywheel detents.
    var rolls: Bool = true
    /// Overrides fractionalDigits for formatted values such as mm:ss.
    var formatter: ((Double) -> String)? = nil

    /// Do not animate a final detent batched with the release transaction.
    @State private var rollsWereEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var formattedString: String {
        formatter?(value) ?? String(format: "%.\(fractionalDigits)f", value)
    }

    var body: some View {
        let animatesValueChange = rolls && rollsWereEnabled && !reduceMotion

        Text(formattedString)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: value))
            .animation(animatesValueChange ? animation : nil, value: value)
            .transaction { transaction in
                guard !animatesValueChange else { return }
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            .onAppear { rollsWereEnabled = rolls }
            .onChange(of: rolls) { _, enabled in rollsWereEnabled = enabled }
            .accessibilityLabel(formattedString)
    }
}

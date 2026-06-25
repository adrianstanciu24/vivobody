//
//  DigitTicker.swift
//  vivobody
//
//  Odometer-style numeric display. Each digit rolls independently: a
//  digit that doesn't change holds still while its neighbor slides.
//  Direction follows the value — rising rolls up, falling rolls down.
//
//  Implementation: each character becomes a clipped ZStack whose inner
//  Text carries an .id tied to its current digit. When the digit
//  changes, the .id changes, and SwiftUI does a remove + insert with a
//  direction-aware .move transition. Unchanged digits stay put because
//  their .id is stable, so no transition fires.
//
//  Use:
//      DigitTicker(value: 195)
//      DigitTicker(value: 2.5, fractionalDigits: 1,
//                  font: Typography.bigMetric)
//

import SwiftUI

struct DigitTicker: View {
    let value: Double
    var font: Font = Typography.metricLg
    var color: Color = Ink.primary
    var fractionalDigits: Int = 0
    var animation: Animation = .spring(response: 0.34, dampingFraction: 0.74)
    /// Optional custom formatter. When provided, takes precedence over
    /// `fractionalDigits`. Non-digit characters in the result (`:`, `.`,
    /// `,`) stay still while digits around them roll independently.
    var formatter: ((Double) -> String)? = nil

    @State private var previousValue: Double = .nan

    private var formattedString: String {
        formatter?(value) ?? String(format: "%.\(fractionalDigits)f", value)
    }

    private enum RollDirection { case up, down }

    var body: some View {
        let direction: RollDirection = (previousValue.isNaN || value >= previousValue) ? .up : .down
        let chars = Array(formattedString)

        HStack(spacing: 0) {
            ForEach(0..<chars.count, id: \.self) { i in
                charSlot(char: chars[i], direction: direction)
            }
        }
        .animation(animation, value: value)
        .onAppear { previousValue = value }
        .onChange(of: value) { _, new in
            previousValue = new
        }
    }

    @ViewBuilder
    private func charSlot(char: Character, direction: RollDirection) -> some View {
        if char.isNumber {
            ZStack {
                Text(String(char))
                    .font(font)
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .id("digit-\(char)")
                    .transition(directedTransition(direction))
            }
            .clipped()
        } else {
            Text(String(char))
                .font(font)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func directedTransition(_ direction: RollDirection) -> AnyTransition {
        switch direction {
        case .up:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .down:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }
}

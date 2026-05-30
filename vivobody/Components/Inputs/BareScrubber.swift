//
//  BareScrubber.swift
//  vivobody
//
//  Vertical drag to adjust a numeric value — the same gesture, feel,
//  and haptics as NumberScrubber, but stripped of all chrome. No
//  chip, no liquid fill, no glass: just the number itself, rendered
//  as a huge monospaced odometer on black.
//
//  This is the instrument-design counterpart to NumberScrubber. The
//  product principles call for "huge, monospaced, weight-bearing
//  numerals" with the value being something you can physically move —
//  so the digit IS the control, not a value sitting inside a control.
//
//  Behaviour (identical to NumberScrubber, intentionally):
//    • up = increase, down = decrease.
//    • Haptics.tick() the frame the value snaps to a new step.
//    • Haptics.rigid() once when hitting the min or max wall.
//    • Past the wall, the number rubber-bands with asymptotic decay.
//    • Release springs the rubber-band back to zero.
//

import SwiftUI

struct BareScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var pointsPerStep: CGFloat = 10
    var fontSize: CGFloat = 104
    var unit: String = ""
    var unitFontSize: CGFloat = 14
    var numberColor: Color = Ink.primary
    var unitColor: Color = Ink.tertiary
    var formatter: ((Double) -> String)? = nil

    @Environment(\.isEnabled) private var isEnabled

    @State private var dragStartValue: Double = 0
    @State private var rubberOffset: CGFloat = 0
    @State private var lastStepReported: Int = 0
    @State private var didHitMin: Bool = false
    @State private var didHitMax: Bool = false
    @State private var isDragging: Bool = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
            DigitTicker(
                value: value,
                font: .system(size: fontSize, weight: .bold, design: .monospaced),
                color: numberColor,
                fractionalDigits: step.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1,
                formatter: formatter
            )

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: unitFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(unitColor)
            }
        }
        .offset(y: rubberOffset)
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: value)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .contentShape(Rectangle())
        .gesture(scrubGesture)
        .accessibilityElement()
        .accessibilityValue("\(formattedValue) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: stepValue(by: 1)
            case .decrement: stepValue(by: -1)
            @unknown default: break
            }
        }
    }

    // MARK: - Gesture

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard isEnabled else { return }
                if !isDragging {
                    isDragging = true
                    dragStartValue = value
                    lastStepReported = 0
                    didHitMin = false
                    didHitMax = false
                }

                let translationY = drag.translation.height
                let stepDelta = Int((-translationY / pointsPerStep).rounded())
                let proposedValue = dragStartValue + Double(stepDelta) * step
                let clamped = min(max(proposedValue, range.lowerBound), range.upperBound)

                if value != clamped {
                    value = clamped
                }

                let absDrag = abs(translationY)
                let inRangeDragPoints = abs(clamped - dragStartValue) / step * pointsPerStep
                let pointsOver = max(0, absDrag - inRangeDragPoints)

                if proposedValue < range.lowerBound {
                    rubberOffset = rubberband(pointsOver)
                    if !didHitMin {
                        Haptics.rigid()
                        didHitMin = true
                    }
                } else if proposedValue > range.upperBound {
                    rubberOffset = -rubberband(pointsOver)
                    if !didHitMax {
                        Haptics.rigid()
                        didHitMax = true
                    }
                } else {
                    rubberOffset = 0
                    didHitMin = false
                    didHitMax = false
                }

                let actualStepDelta = Int(((clamped - dragStartValue) / step).rounded())
                if actualStepDelta != lastStepReported {
                    Haptics.tick()
                    lastStepReported = actualStepDelta
                }
            }
            .onEnded { _ in
                isDragging = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    rubberOffset = 0
                }
            }
    }

    // MARK: - Helpers

    /// iOS-style asymptotic decay: approaches `max` as input grows.
    private func rubberband(_ x: CGFloat, maxStretch: CGFloat = 50) -> CGFloat {
        maxStretch * (1 - 1 / (x / maxStretch + 1))
    }

    private func stepValue(by direction: Int) {
        let next = value + Double(direction) * step
        let clamped = min(max(next, range.lowerBound), range.upperBound)
        if clamped != value {
            value = clamped
            Haptics.tick()
        } else {
            Haptics.rigid()
        }
    }

    private var formattedValue: String {
        if let formatter { return formatter(value) }
        let isIntegerStep = step.truncatingRemainder(dividingBy: 1) == 0
        return isIntegerStep ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

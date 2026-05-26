//
//  NumberScrubber.swift
//  vivobody
//
//  Vertical drag to adjust a numeric value.
//    • up   = increase (gravity-as-metaphor: you're lifting it)
//    • down = decrease
//
//  Behavior:
//    • Haptics.tick() fires the exact frame the value snaps to a new step.
//    • Haptics.rigid() fires once when the user hits the min or max wall.
//    • Past the wall, the visual rubber-bands with iOS-style asymptotic decay.
//    • Release springs the rubber-band back to zero.
//

import SwiftUI

struct NumberScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var pointsPerStep: CGFloat = 12
    var unit: String = ""
    var label: String? = nil
    /// Size of the rolled-digit value text. Defaults to the
    /// gallery-presentation 64pt; compositions that embed the
    /// scrubber inside a larger layout (e.g. ActiveExerciseCard) pass
    /// a smaller value.
    var valueFontSize: CGFloat = 64
    /// Vertical padding inside the rounded card. Trim alongside
    /// `valueFontSize` for compact embeddings.
    var verticalPadding: CGFloat = 28

    @State private var dragStartValue: Double = 0
    @State private var rubberOffset: CGFloat = 0
    @State private var lastStepReported: Int = 0
    @State private var didHitMin: Bool = false
    @State private var didHitMax: Bool = false
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            if let label {
                Text(label)
                    .sectionLabelStyle(0.50)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                DigitTicker(
                    value: value,
                    font: .system(size: valueFontSize, weight: .bold, design: .rounded),
                    color: .white,
                    fractionalDigits: step.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
                )

                if !unit.isEmpty {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            .offset(y: rubberOffset)
            .scaleEffect(isDragging ? 1.03 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .glassChip(cornerRadius: 22, tint: isDragging ? Tint.primary : nil)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .gesture(scrubGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        .accessibilityElement()
        .accessibilityLabel(label ?? "Value")
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

    /// iOS-style asymptotic decay: approaches `max` as input grows. ~50pt cap.
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
        let isIntegerStep = step.truncatingRemainder(dividingBy: 1) == 0
        return isIntegerStep ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

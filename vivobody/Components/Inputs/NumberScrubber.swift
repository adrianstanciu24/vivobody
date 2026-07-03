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
    /// Optional custom value formatter (e.g. mm:ss for timed holds).
    /// When provided, takes precedence over the integer/decimal
    /// default. Mirrors BareScrubber's `formatter`.
    var formatter: ((Double) -> String)? = nil
    /// Voice of the per-step tick. Pass `.deep` on load scrubbers so
    /// weight sounds heavier than reps/sets/duration.
    var tickTone: Haptics.TickTone = .standard

    @State private var dragStartValue: Double = 0
    @State private var rubberOffset: CGFloat = 0
    @State private var lastStepReported: Int = 0
    @State private var didHitMin: Bool = false
    @State private var didHitMax: Bool = false
    @State private var isDragging: Bool = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Value-settle spring. When Reduce Motion is on, skip the
    /// decorative spring so the number snaps to its new value.
    private var valueAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75)
    }

    /// Drag-state transition (scale, shadow, tint). When Reduce
    /// Motion is on, snap between states instead of springing.
    private var dragStateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)
    }

    var body: some View {
        VStack(spacing: 4) {
            if let label {
                Text(label)
                    .sectionLabelStyle(Opacity.medium)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                DigitTicker(
                    value: value,
                    font: .system(size: valueFontSize, weight: .bold, design: .rounded),
                    color: Ink.primary,
                    fractionalDigits: step.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1,
                    formatter: formatter
                )

                if !unit.isEmpty {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .offset(y: rubberOffset)
            .scaleEffect(reduceMotion ? 1.0 : (isDragging ? 1.03 : 1.0))
            .animation(valueAnimation, value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, verticalPadding)
        .background {
            LiquidFill(
                fraction: fillFraction,
                cornerRadius: Radius.card,
                tint: fluidTint,
                isDragging: isDragging
            )
        }
        .glassChip(cornerRadius: Radius.card, tint: isDragging ? Tint.primary : nil, interactive: true)
        .overlay {
            // Bottom inner shadow — gives the chip a sense of
            // containment, like the liquid is sitting in a real
            // vessel with a darker base lip.
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
                .blur(radius: 0.6)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
        .shadow(
            color: isDragging ? Tint.primary.opacity(0.35) : Color.black.opacity(0.45),
            radius: isDragging ? 14 : 8,
            y: isDragging ? 5 : 3
        )
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .gesture(scrubGesture)
        .animation(dragStateAnimation, value: isDragging)
        .accessibilityElement()
        .accessibilityLabel(label ?? "Adjustable value")
        .accessibilityValue("\(formattedValue)\(unit.isEmpty ? "" : " \(unit)")")
        .accessibilityHint("Swipe up or down to change")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: stepValue(by: 1)
            case .decrement: stepValue(by: -1)
            @unknown default: break
            }
        }
        .focusable()
        .accessibilityRespondsToUserInteraction(true)
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
                    // Pitch tracks the drag: each step from the grab
                    // point shifts the tick ~30 cents, so scrubbing up
                    // literally sounds like the number going up.
                    Haptics.tick(pitch: Double(actualStepDelta) / 20, tone: tickTone)
                    lastStepReported = actualStepDelta
                }
            }
            .onEnded { _ in
                isDragging = false
                if reduceMotion {
                    rubberOffset = 0
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                        rubberOffset = 0
                    }
                }
            }
    }

    // MARK: - Helpers

    /// iOS-style asymptotic decay: approaches `max` as input grows. ~50pt cap.
    private func rubberband(_ x: CGFloat, maxStretch: CGFloat = 50) -> CGFloat {
        maxStretch * (1 - 1 / (x / maxStretch + 1))
    }

    private func stepValue(by direction: Int) {
        guard isEnabled else { return }
        let next = value + Double(direction) * step
        let clamped = min(max(next, range.lowerBound), range.upperBound)
        if clamped != value {
            value = clamped
            Haptics.tick(pitch: Double(direction) * 0.15, tone: tickTone)
        } else {
            Haptics.rigid()
        }
    }

    private var formattedValue: String {
        if let formatter { return formatter(value) }
        let isIntegerStep = step.truncatingRemainder(dividingBy: 1) == 0
        return isIntegerStep ? "\(Int(value))" : String(format: "%.1f", value)
    }

    /// Position of the value within `range`, clamped to [0, 1] and
    /// floored at a tiny minimum so the fluid is always visible at
    /// the very bottom of the range. The minimum is the affordance:
    /// even at zero, a sliver of liquid hints that the chip *holds*
    /// something — and that the level is what you adjust.
    private var fillFraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let raw = (value - range.lowerBound) / span
        return max(0.06, min(1.0, raw))
    }

    private var fluidTint: Color {
        isEnabled ? Tint.primary : Ink.tertiary
    }
}

/// Beaker-style fluid fill that sits inside the glass chip and rises
/// with the scrubber's value. A soft warm-white halo at the top of
/// the fluid plays the role of the meniscus — light catching the
/// waterline rather than a drawn separator. The level is the value,
/// and the value is something you can move.
///
/// Drawn as a `.background` on the scrubber content so the digits
/// always read on top of the liquid. The whole view is clipped to
/// the chip's rounded rectangle so the fluid hugs the corners.
private struct LiquidFill: View {
    let fraction: Double
    let cornerRadius: CGFloat
    let tint: Color
    let isDragging: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Warm cream-white. Light reflecting off a tinted fluid is
    /// brighter and less saturated than the fluid's body colour,
    /// which is what stops the highlight reading as a UI rule.
    private static let highlight = Color(.sRGB, red: 1.00, green: 0.93, blue: 0.84, opacity: 1.0)

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let fillH = max(0, h * CGFloat(fraction))
            let bottomOpacity: Double = isDragging ? 0.42 : 0.30
            let topOpacity: Double = isDragging ? 0.14 : 0.08
            let haloPeak: Double = isDragging ? 0.55 : 0.40

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: [
                            tint.opacity(topOpacity),
                            tint.opacity(bottomOpacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        colors: [
                            Self.highlight.opacity(0),
                            Self.highlight.opacity(haloPeak),
                            Self.highlight.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 5)
                    .offset(y: -2.5)
                    .blur(radius: 0.6)
                    .opacity(fraction > 0.02 ? 1 : 0)
                }
                .frame(height: fillH)
            }
            .frame(width: geo.size.width, height: h, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: fraction)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isDragging)
        .allowsHitTesting(false)
    }
}

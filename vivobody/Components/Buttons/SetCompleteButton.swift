//
//  SetCompleteButton.swift
//  vivobody
//
//  The signature interaction: one big tap to complete a set.
//  Owns no business state — emits a toggle event, animates from `isComplete`.
//
//  Composition of effects on idle → complete:
//    1. Haptics.crescendo()
//    2. Card background fills with accent.
//    3. Numbers spring-overshoot (1.0 → 1.06 → 1.0).
//    4. Chevron morphs into a checkmark (stroke draw-on).
//    5. A single radial ring expands from the tap point and fades.
//
//  Complete → idle (undo): Haptics.soft() and the same path in reverse.
//

import SwiftUI

enum SetIntensity {
    case standard
    case peak
}

struct SetCompleteButton: View {
    let reps: Int
    let weight: Double
    let isComplete: Bool
    var intensity: SetIntensity = .standard
    /// When set, the button renders this verb (e.g. "Complete set")
    /// instead of repeating the reps × weight numbers. The numbers
    /// already live large above the button in the instrument layout,
    /// so echoing them here would be the duplication the redesign
    /// deletes. Icons are reserved for navigation — the action is a
    /// word.
    var title: String? = nil
    /// Overrides the spoken VoiceOver label. Used for timed holds,
    /// where "8 reps at 0 pounds" would be meaningless — the card
    /// passes "Hold 0:45" instead.
    var accessibilityLabelOverride: String? = nil
    let onToggle: () -> Void

    @State private var pressScale: CGFloat = 1
    @State private var numberScale: CGFloat = 1
    @State private var rippleId: Int = 0
    @State private var ripplePoint: CGPoint = .zero
    @State private var size: CGSize = .zero

    /// Sticky flag — once we've decided this gesture is a drag (not a
    /// tap), we stay decided for the rest of the gesture. Otherwise a
    /// user who drifts past the threshold and then slows back inside
    /// could "rescue" a tap they didn't actually intend.
    @State private var dragCanceled: Bool = false

    /// The flood-fill colour the moment the set is completed.
    private let accent = Tint.complete
    /// The live, "you're about to do this" colour worn by the idle
    /// button — rim, verb text, chevron.
    private let liveAccent = Tint.inProgress

    var body: some View {
        ZStack {
            background
            ripple
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .scaleEffect(pressScale)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { size = geo.size }
                    .onChange(of: geo.size) { _, new in size = new }
            }
        )
        .gesture(tapGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelOverride ?? "\(reps) reps at \(Int(weight)) pounds")
        .accessibilityValue(isComplete ? "completed" : "not completed")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isComplete ? "Double tap to undo." : "Double tap to complete the set.")
    }

    // MARK: - Layers

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return shape
            .fill(isComplete ? accent.opacity(0.95) : liveAccent.opacity(0.10))
            // Top specular sheen — strongest on the idle state where
            // the surface needs the most cue that it's pressable glass.
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isComplete ? 0.18 : 0.20),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.55)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            // Bottom inner darkening — the puck has a base lip the
            // light doesn't reach, which is what makes the top read
            // as raised.
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(isComplete ? 0.25 : 0.30)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.50)
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
                .clipShape(shape)
                .blendMode(.multiply)
                .allowsHitTesting(false)
            }
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: isComplete
                                ? [Color.white.opacity(0.55), Color.white.opacity(0.10)]
                                : [liveAccent.opacity(0.65), liveAccent.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
            )
            // Completion glow only — gold flood when done. Idle stays
            // a faint lift, no ambient bloom on the live state.
            .shadow(
                color: isComplete ? accent.opacity(0.50) : liveAccent.opacity(0.16),
                radius: isComplete ? 24 : 10,
                y: isComplete ? 9 : 4
            )
            .shadow(color: .black.opacity(0.50), radius: 6, y: 3)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isComplete)
    }

    private var ripple: some View {
        Ripple(triggerId: rippleId, origin: ripplePoint, color: isComplete ? .white : liveAccent)
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let title {
            HStack(alignment: .center, spacing: 0) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(isComplete ? Color.black : liveAccent)
                Spacer(minLength: 8)
                statusIndicator
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isComplete)
        } else {
            HStack(alignment: .center, spacing: 0) {
                numberBlock(value: "\(reps)", unit: "reps")
                multiplier
                numberBlock(value: formattedWeight, unit: "lb")
                Spacer(minLength: 8)
                statusIndicator
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .foregroundStyle(isComplete ? Color.black : Color.white)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isComplete)
        }
    }

    private func numberBlock(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .scaleEffect(numberScale)
            Text(unit)
                .font(Typography.metricUnit)
                .opacity(isComplete ? 0.65 : 0.55)
        }
    }

    private var multiplier: some View {
        Text("×")
            .font(.system(size: 22, weight: .medium, design: .rounded))
            .opacity(0.35)
            .padding(.horizontal, 14)
            .offset(y: -8)
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(isComplete ? Color.black.opacity(0.12) : liveAccent.opacity(0.14))
                .frame(width: 44, height: 44)

            if isComplete {
                Checkmark()
                    .trim(from: 0, to: 1)
                    .stroke(
                        Color.black,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 18, height: 14)
                    .transition(
                        .asymmetric(
                            insertion: .modifier(active: StrokeDrawIn(progress: 0), identity: StrokeDrawIn(progress: 1)),
                            removal: .opacity.combined(with: .scale(scale: 0.6))
                        )
                    )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(liveAccent)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.62), value: isComplete)
    }

    // MARK: - Gesture

    /// Actual-translation threshold for "this is a drag, not a tap."
    /// 10pt matches what UIButton inside UIScrollView uses internally.
    private let dragCancelDistance: CGFloat = 10

    /// Predicted-end-translation threshold for "this is a flick" —
    /// catches short fast swipes that travel less than 10pt before
    /// lift-off but have enough momentum to commit a card change in
    /// the SwipePager. Anything above this is unmistakably a swipe.
    private let flickCancelDistance: CGFloat = 35

    private var tapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Lock in "drag" the moment we cross the threshold.
                // Sticky — a drift past 10pt that returns inside
                // shouldn't reanimate a "tap" that the user didn't
                // intend.
                if !dragCanceled, isOverDragThreshold(value) {
                    dragCanceled = true
                }
                let inside = isInside(value.location)
                let target: CGFloat = (inside && !dragCanceled) ? 0.975 : 1
                if pressScale != target {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                        pressScale = target
                    }
                }
                if inside { ripplePoint = value.location }
            }
            .onEnded { value in
                defer { dragCanceled = false }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                    pressScale = 1
                }
                // Fire only if (a) we haven't already decided this is
                // a drag, (b) the release wasn't a fast flick, and
                // (c) the finger lifted inside the button.
                if !dragCanceled,
                   !isFlick(value),
                   isInside(value.location) {
                    fire(at: value.location)
                }
            }
    }

    private func isInside(_ p: CGPoint) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        return p.x >= 0 && p.x <= size.width && p.y >= 0 && p.y <= size.height
    }

    private func isOverDragThreshold(_ value: DragGesture.Value) -> Bool {
        let dx = abs(value.translation.width)
        let dy = abs(value.translation.height)
        return max(dx, dy) > dragCancelDistance
    }

    /// Catches short fast flicks — the predictedEndTranslation
    /// reflects velocity, so even a 6pt actual swipe will have a
    /// large predicted value if the user threw their finger.
    private func isFlick(_ value: DragGesture.Value) -> Bool {
        let pdx = abs(value.predictedEndTranslation.width)
        let pdy = abs(value.predictedEndTranslation.height)
        return max(pdx, pdy) > flickCancelDistance
    }

    private func fire(at point: CGPoint) {
        if isComplete {
            Haptics.soft()
        } else {
            switch intensity {
            case .standard: Haptics.crescendo()
            case .peak:     Haptics.swell()
            }
        }
        ripplePoint = point
        rippleId &+= 1

        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            numberScale = 1.06
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.08)) {
            numberScale = 1
        }
        onToggle()
    }

    private var formattedWeight: String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(format: "%.1f", weight)
    }
}

// MARK: - Ripple

private struct Ripple: View {
    let triggerId: Int
    let origin: CGPoint
    let color: Color

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: 60, height: 60)
            .position(origin == .zero ? CGPoint(x: 0, y: 0) : origin)
            .scaleEffect(scale, anchor: .center)
            .opacity(opacity)
            .onChange(of: triggerId) { _, _ in
                scale = 0.2
                opacity = 0.7
                withAnimation(.easeOut(duration: 0.55)) {
                    scale = 4.5
                    opacity = 0
                }
            }
    }
}

// MARK: - Checkmark path

private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct StrokeDrawIn: ViewModifier, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.mask(
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * progress, height: geo.size.height)
            }
        )
    }
}

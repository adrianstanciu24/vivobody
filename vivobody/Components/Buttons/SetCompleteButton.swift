//
//  SetCompleteButton.swift
//  vivobody
//
//  The signature interaction: one big tap to complete a set.
//  Owns no business state — emits a toggle event, animates from `isComplete`.
//
//  Composition of effects on idle → complete:
//    1. Haptics.crescendo()
//    2. Glass surface tints from live accent to completion accent.
//    3. Numbers spring-overshoot (1.0 → 1.06 → 1.0).
//    4. Chevron morphs into a checkmark (stroke draw-on).
//    5. A single radial ring expands from the tap point and fades.
//
//  Complete → idle (undo): Haptics.soft() and the same path in reverse.
//
//  The surface is Liquid Glass (.glassEffect) with the accent as its
//  tint — not an opaque fill. The system material owns the specular
//  highlights, rim lighting, and accessibility fallbacks (Reduce
//  Transparency / Increase Contrast), so no hand-drawn sheens,
//  darkening overlays, or stroke gradients are needed.
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit
    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }
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

    /// The flood-fill colour the moment the set is completed. Same
    /// accent as the live state — completion reads through the solid
    /// fill, the checkmark draw-on, and the haptic, not a new hue.
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
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .scaleEffect(pressScale)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { size = geo.size }
                    .onChange(of: geo.size) { _, new in size = new }
            }
        )
        .gesture(tapGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelOverride ?? "\(reps) reps at \(WeightFormatter.string(weight, unit: unit, fractionDigits: 0, includeUnit: false)) \(unit.displayName.lowercased())")
        .accessibilityValue(isComplete ? "completed" : "not completed")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isComplete ? "Double tap to undo." : "Double tap to complete the set.")
    }

    // MARK: - Layers

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let glassTint = isComplete ? accent : liveAccent
        // Completion floods the surface; idle stays a faint lift so the
        // accent verb and chevron read against the glass instead of
        // drowning in a same-hue orange wash.
        let surfaceTint = isComplete ? accent : liveAccent.opacity(0.16)
        return shape
            .fill(reduceTransparency
                    ? glassTint.opacity(isComplete ? 1.0 : 0.35)
                    : glassTint.opacity(isComplete ? 0.85 : 0.10))
            .glassTinted(surfaceTint, interactive: true, in: shape)
            // Completion glow — accent bloom when done. Idle stays a
            // faint lift, no ambient bloom on the live state.
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
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let title {
            HStack(alignment: .center, spacing: 0) {
                Text(title)
                    .font(Typography.title)
                    .tracking(0.4)
                    .foregroundStyle(isComplete ? Tint.onAccent : liveAccent)
                Spacer(minLength: 8)
                statusIndicator
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isComplete)
        } else {
            HStack(alignment: .center, spacing: 0) {
                numberBlock(value: "\(reps)", unit: "reps")
                multiplier
                numberBlock(value: formattedWeight, unit: unit.symbol)
                Spacer(minLength: 8)
                statusIndicator
            }
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .foregroundStyle(isComplete ? Tint.onAccent : Ink.primary)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isComplete)
        }
    }

    private func numberBlock(value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.metricLg)
                .monospacedDigit()
                .scaleEffect(numberScale)
            Text(unit)
                .font(Typography.metricUnit)
                .opacity(isComplete ? 0.65 : 0.55)
        }
    }

    private var multiplier: some View {
        Text("×")
            .font(Typography.statValue)
            .opacity(0.35)
            .padding(.horizontal, Space.lg)
            .offset(y: -8)
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(isComplete ? Tint.onAccent.opacity(0.12) : Surface.cardTint)
                .frame(width: 44, height: 44)

            if isComplete {
                Checkmark()
                    .trim(from: 0, to: 1)
                    .stroke(
                        Tint.onAccent,
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
                    .font(Typography.headline)
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
        WeightFormatter.string(weight, unit: unit, includeUnit: false)
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

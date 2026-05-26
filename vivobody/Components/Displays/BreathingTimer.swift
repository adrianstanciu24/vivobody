//
//  BreathingTimer.swift
//  vivobody
//
//  The rest-timer screen. Most of a workout is rest, so this isn't a modal —
//  it's the home base between sets.
//
//  Behavior:
//    • A soft circle breathes at ~12 BPM (5s/cycle), slower than resting heart
//      rate, which actually calms people down.
//    • At T-10s the breath rate doubles (≈30 BPM) and the color warms from
//      cool blue to amber — the screen begins urging you.
//    • At T-3, T-2, T-1 distinct escalating haptics fire (light → medium → heavy)
//      — a starter-pistol shape, not three identical beeps.
//    • At T-0 a success haptic lands. The breath freezes; "GO" appears.
//
//  Gestures (no buttons):
//    • Pull DOWN past threshold → skip rest now.
//    • Pull UP past threshold → add 30 seconds.
//    • Below threshold, the card rubber-bands back on release.
//    • Crossing the threshold mid-drag fires Haptics.selection() so you feel
//      the commit point in your hand without looking.
//

import SwiftUI

struct BreathingTimer: View {
    let duration: TimeInterval
    var nextSetLabel: String? = nil
    var onComplete: () -> Void = {}
    var onSkip: () -> Void = {}
    var onExtend: (TimeInterval) -> Void = { _ in }

    @State private var endTime: Date
    @State private var startTime: Date
    @State private var totalDuration: TimeInterval
    @State private var secondsRemaining: Int
    @State private var hasFinished: Bool = false
    @State private var hasFiredWarning: Bool = false
    @State private var lastTickSecond: Int = -1

    @State private var dragOffset: CGFloat = 0
    @State private var pastSkipThreshold: Bool = false
    @State private var pastExtendThreshold: Bool = false

    private let threshold: CGFloat = 90
    private let maxDrag: CGFloat = 140

    // Cool start → warm-orange landing. The cool side was originally
    // a vivid blue; toned to a desaturated slate so it harmonises with
    // the warm app palette while still reading as a calm "low energy"
    // state. The warm side lands on Tint.primary so the timer feels
    // like part of the same world as the rest of the app.
    private let cool = Color(.sRGB, red: 0.55, green: 0.65, blue: 0.78, opacity: 1)
    private let warm = Tint.primary

    init(
        duration: TimeInterval,
        nextSetLabel: String? = nil,
        onComplete: @escaping () -> Void = {},
        onSkip: @escaping () -> Void = {},
        onExtend: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.duration = duration
        self.nextSetLabel = nextSetLabel
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onExtend = onExtend
        let now = Date()
        let end = now.addingTimeInterval(duration)
        self._startTime = State(initialValue: now)
        self._endTime = State(initialValue: end)
        self._totalDuration = State(initialValue: duration)
        self._secondsRemaining = State(initialValue: Int(duration.rounded(.up)))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let now = context.date
            let remainingExact = max(0, endTime.timeIntervalSince(now))
            let elapsed = max(0, now.timeIntervalSince(startTime))
            let accelerated = remainingExact > 0 && remainingExact <= 10
            let warmth = warmthCurve(remaining: remainingExact)
            let scale = breathScale(elapsed: elapsed, accelerated: accelerated)
            let progress = min(1, max(0, 1 - remainingExact / totalDuration))
            let color = lerpColor(cool, warm, t: warmth)

            ZStack {
                background(color: color)
                breathRipples(elapsed: elapsed, accelerated: accelerated, color: color)
                breathLayers(scale: scale, color: color, progress: progress)
                centerContent(remaining: remainingExact)
                restPillOverlay
                swipeAffordances
                hints
                nextSet
            }
            .offset(y: dragOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .contentShape(Rectangle())
            .gesture(skipOrExtendGesture)
        }
        .onAppear { Haptics.prepare() }
        .onChange(of: secondsRemaining) { _, new in handleSecondTick(new) }
        .task(id: endTime) {
            while !Task.isCancelled {
                let r = max(0, Int(endTime.timeIntervalSinceNow.rounded(.up)))
                if r != secondsRemaining { secondsRemaining = r }
                if r == 0 { break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    // MARK: - Layers

    /// Atmospheric backdrop: a radial vignette that pulls the eye
    /// toward the orb (which is the light source) and a faint ambient
    /// grain layer to kill banding and add photographic depth.
    private func background(color: Color) -> some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [
                    color.opacity(0.10),
                    Color(.sRGB, white: 0.025, opacity: 1),
                    Color.black
                ],
                center: .center,
                startRadius: 80,
                endRadius: 460
            )
            Grain(intensity: 0.7)
                .blendMode(.plusLighter)
                .opacity(0.55)
        }
        .ignoresSafeArea()
    }

    /// Concentric breath rings emanating from the orb on each cycle.
    /// Three rings staggered by 1/3 of the breath period — together
    /// they read as a slow sonar pulse synchronised to the orb's
    /// inhale/exhale, reinforcing the metaphor without competing
    /// with the timer's information density.
    private func breathRipples(elapsed: Double, accelerated: Bool, color: Color) -> some View {
        let period = accelerated ? 2.0 : 5.0
        let ringCount = 3
        return ZStack {
            ForEach(0..<ringCount, id: \.self) { i in
                let offset = Double(i) * (period / Double(ringCount))
                let phase = ((elapsed + offset).truncatingRemainder(dividingBy: period)) / period
                let scale = 1.0 + phase * 1.8
                let alpha = max(0, (1.0 - phase) * 0.10)
                Circle()
                    .stroke(color.opacity(alpha), lineWidth: 1.2)
                    .frame(width: 240, height: 240)
                    .scaleEffect(scale)
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// The signature element. Layered to read as a translucent glass
    /// sphere on dark ground:
    ///   1. Atmospheric halo (scaled, soft).
    ///   2. Contact shadow ellipse below (pedestal).
    ///   3. Sphere body with a Fresnel rim — bright spec upper-left,
    ///      mid body, dark edge — the single biggest cue that "this
    ///      is round, not a disc."
    ///   4. Inner rim shadow ring (subtle dark gradient on the lip).
    ///   5. Bounce-light arc on the lower edge (light reflecting up
    ///      off the floor).
    ///   6. Specular cap glow.
    ///   7. Progress ring — full circumference, fixed size so the
    ///      reading stays stable while the body breathes.
    private func breathLayers(scale: Double, color: Color, progress: Double) -> some View {
        ZStack {
            // 1. Atmosphere — soft outer halo. Larger blur as the
            // timer warms gives the impression of heat radiating
            // outward.
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: 380, height: 380)
                .scaleEffect(scale * 1.05)
                .blur(radius: 56)

            // 2. Contact shadow — anchors the orb on a notional floor.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.65),
                            Color.black.opacity(0.30),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 36)
                .offset(y: 138)
                .blur(radius: 10)

            // 3. Sphere body — Fresnel-shaded radial gradient. The
            // mid-tone is brightest; the rim darkens; the upper-left
            // is the spec hot spot. This is what makes it a sphere.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: color.opacity(0.68), location: 0.00),
                            .init(color: color.opacity(0.50), location: 0.40),
                            .init(color: color.opacity(0.22), location: 0.78),
                            .init(color: color.opacity(0.06), location: 0.95),
                            .init(color: color.opacity(0.00), location: 1.00),
                        ]),
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(scale)
                .blendMode(.plusLighter)

            // 4. Inner rim shadow — a faint dark inner stroke that
            // sells "this is the lip of a glass sphere" by darkening
            // the edge where the body curves away.
            Circle()
                .stroke(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.35)
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 120
                    ),
                    lineWidth: 14
                )
                .frame(width: 240, height: 240)
                .scaleEffect(scale)
                .blendMode(.multiply)

            // 5. Bounce light — a thin warm arc along the lower rim,
            // simulating light reflecting up off the ground onto the
            // underside of the sphere. Sells dimensionality.
            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(
                    color.opacity(0.45),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .blur(radius: 2.5)
                .frame(width: 234, height: 234)
                .scaleEffect(scale)
                .blendMode(.plusLighter)

            // 6. Specular cap — small bright spot upper-left so the
            // orb reads as a glass sphere catching light, not a 2D
            // disc.
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 70, height: 70)
                .blur(radius: 22)
                .offset(x: -44, y: -42)
                .scaleEffect(scale)
                .blendMode(.plusLighter)

            // 7. Progress ring — full circumference. NOT scaled with
            // the breath so the progress arc stays a stable reading.
            // Track sits at very low opacity; the traveled portion
            // pops with a glow that haloes the leading edge.
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.65), radius: 10)
                    .shadow(color: color.opacity(0.35), radius: 22)
            }
            .frame(width: 256, height: 256)
        }
    }

    /// Center content: only the big time and a small total under it
    /// so the orb's body has room to breathe. The "Rest" / "Go"
    /// label is hoisted out to its own glass pill above the orb in
    /// `restPillOverlay` — that's the composition fix.
    private func centerContent(remaining: TimeInterval) -> some View {
        VStack(spacing: 4) {
            DigitTicker(
                value: remaining,
                font: .system(size: 76, weight: .bold, design: .rounded),
                color: .white,
                formatter: { time in
                    let total = Int(time.rounded(.up))
                    return String(format: "%d:%02d", total / 60, total % 60)
                }
            )
            .shadow(color: .black.opacity(0.55), radius: 8, y: 2)

            Text("of \(formatted(totalDuration))")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.40))
                .opacity(hasFinished ? 0 : 1)
                .padding(.top, 4)
        }
    }

    /// "Rest" / "Go" surfaced as a small glass pill floating above
    /// the orb. Owning its own surface gives the composition a
    /// header beat — eyes land here first, then drop into the
    /// number, then read the progress ring around the body.
    private var restPillOverlay: some View {
        VStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(hasFinished ? Tint.success : Tint.primary)
                    .frame(width: 6, height: 6)
                    .shadow(color: (hasFinished ? Tint.success : Tint.primary).opacity(0.7), radius: 3)
                Text(hasFinished ? "Go" : "Rest")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .tracking(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassPill()
            .padding(.top, 64)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    /// Two always-visible swipe affordances at the top and bottom
    /// edges of the screen, brightening as the user crosses each
    /// commit threshold. Without these the gestures are invisible
    /// until you start dragging — discoverability suffers.
    private var swipeAffordances: some View {
        VStack {
            affordanceChip(
                symbol: "chevron.compact.down",
                label: "Skip",
                visibility: hintVisibility(dragOffset, direction: .down)
            )
            .padding(.top, 130)
            Spacer()
            affordanceChip(
                symbol: "chevron.compact.up",
                label: "+30s",
                visibility: hintVisibility(dragOffset, direction: .up)
            )
            .padding(.bottom, 140)
        }
        .allowsHitTesting(false)
    }

    private func affordanceChip(symbol: String, label: String, visibility: Double) -> some View {
        // visibility goes 0 → 1 as the user pulls toward the
        // threshold. We map it onto opacity + a faint scale so the
        // chip "wakes up" mid-drag without disappearing at rest.
        let restingOpacity = 0.22
        let activeOpacity = 0.95
        let opacity = restingOpacity + (activeOpacity - restingOpacity) * visibility
        return VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(.white.opacity(opacity))
        .scaleEffect(0.96 + 0.06 * visibility)
    }

    /// Legacy mid-drag hint pill kept around for the strong commit
    /// affordance — appears centered over the action zone with full
    /// "Skip rest" / "+30 sec" copy once the user passes the
    /// threshold. The thin always-on chevrons handle discoverability;
    /// these handle confirmation.
    private var hints: some View {
        VStack {
            hintPill(symbol: "arrow.down", label: "Skip rest",
                     visibility: hintVisibility(dragOffset, direction: .down))
                .padding(.top, 92)
                .opacity(dragOffset > 0 ? 1 : 0)
            Spacer()
            hintPill(symbol: "arrow.up", label: "+30 sec",
                     visibility: hintVisibility(dragOffset, direction: .up))
                .padding(.bottom, 100)
                .opacity(dragOffset < 0 ? 1 : 0)
        }
    }

    private func hintPill(symbol: String, label: String, visibility: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassPill(tint: Tint.primary)
        .opacity(visibility)
        .scaleEffect(0.92 + 0.08 * visibility)
    }

    @ViewBuilder
    private var nextSet: some View {
        if let nextSetLabel {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Text("Next")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tint.primary)
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 12)
                    Text(nextSetLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassPill()
                .padding(.bottom, 44)
            }
        }
    }

    // MARK: - Gesture

    private var skipOrExtendGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                let raw = v.translation.height
                dragOffset = clampWithRubber(raw)

                let down = raw > threshold
                let up = raw < -threshold
                if down && !pastSkipThreshold {
                    pastSkipThreshold = true
                    Haptics.selection()
                }
                if !down { pastSkipThreshold = false }
                if up && !pastExtendThreshold {
                    pastExtendThreshold = true
                    Haptics.selection()
                }
                if !up { pastExtendThreshold = false }
            }
            .onEnded { v in
                let raw = v.translation.height
                if raw > threshold {
                    Haptics.thunk()
                    skipNow()
                } else if raw < -threshold {
                    Haptics.tick()
                    extend(by: 30)
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    dragOffset = 0
                }
                pastSkipThreshold = false
                pastExtendThreshold = false
            }
    }

    private func clampWithRubber(_ raw: CGFloat) -> CGFloat {
        // Linear up to threshold, asymptotic decay past it.
        let sign: CGFloat = raw >= 0 ? 1 : -1
        let mag = abs(raw)
        if mag <= threshold { return raw }
        let extra = mag - threshold
        let decayed = maxDrag - threshold - (maxDrag - threshold) / (extra / 40 + 1)
        return sign * (threshold + decayed)
    }

    // MARK: - State transitions

    private func handleSecondTick(_ remaining: Int) {
        guard remaining >= 0 else { return }
        if remaining == 10 && !hasFiredWarning {
            Haptics.breath()
            hasFiredWarning = true
        }
        if remaining == lastTickSecond { return }
        lastTickSecond = remaining
        switch remaining {
        case 3: Haptics.tick()
        case 2: Haptics.soft()
        case 1: Haptics.thunk()
        case 0:
            if !hasFinished {
                hasFinished = true
                Haptics.success()
                onComplete()
            }
        default: break
        }
    }

    private func skipNow() {
        if !hasFinished {
            // First swipe on a still-counting timer: snap to 0 / GO
            // state, but stay on the overlay. The user has to commit
            // with a second swipe to actually return to the exercise
            // card. This gives a confirmation beat — a moment to
            // breathe in the "I'm ready" state before re-engaging.
            endTime = Date()
            hasFinished = true
        } else {
            // Second swipe — already at the GO state, either from a
            // previous skip or from a manual extend that ran out
            // again. Now dismiss for real.
            onSkip()
        }
    }

    private func extend(by seconds: TimeInterval) {
        endTime = endTime.addingTimeInterval(seconds)
        totalDuration += seconds
        hasFiredWarning = false
        hasFinished = false
        onExtend(seconds)
    }

    // MARK: - Math

    /// 12 BPM normal (5s period, amplitude 0.08).
    /// 30 BPM accelerated (2s period, amplitude 0.10).
    /// Starts at scale=1.0 at t=0 thanks to (1 - cos) phase.
    private func breathScale(elapsed: Double, accelerated: Bool) -> Double {
        let period = accelerated ? 2.0 : 5.0
        let amplitude = accelerated ? 0.10 : 0.08
        let phase = (1 - cos(2 * .pi * elapsed / period)) / 2
        return 1.0 + amplitude * phase
    }

    /// 0 when remaining > 10s, ramps to 1 at remaining = 0.
    private func warmthCurve(remaining: TimeInterval) -> Double {
        let w = (10 - remaining) / 10
        return min(1, max(0, w))
    }

    private func lerpColor(_ a: Color, _ b: Color, t: Double) -> Color {
        let aRGB = a.resolve(in: .init())
        let bRGB = b.resolve(in: .init())
        let r = Double(aRGB.red) + (Double(bRGB.red) - Double(aRGB.red)) * t
        let g = Double(aRGB.green) + (Double(bRGB.green) - Double(aRGB.green)) * t
        let bl = Double(aRGB.blue) + (Double(bRGB.blue) - Double(aRGB.blue)) * t
        return Color(.sRGB, red: r, green: g, blue: bl, opacity: 1)
    }

    private enum DragDirection { case up, down }

    private func hintVisibility(_ offset: CGFloat, direction: DragDirection) -> Double {
        let signed: CGFloat = (direction == .down) ? offset : -offset
        if signed <= 0 { return 0 }
        return min(1, Double(signed / threshold))
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Static ambient grain overlay. Drawn once into a Canvas with a
/// fixed seed of randomised dots so the noise stays the same across
/// frames (Canvas re-running with `Double.random` would re-roll the
/// pattern every animation tick and read as static interference,
/// not film grain). 600 dots is plenty for screen-sized surfaces;
/// the layer is composed with `.plusLighter` upstream so the dots
/// contribute a faint highlight, not a darkening texture.
private struct Grain: View {
    var intensity: Double = 1.0

    @State private var dots: [Dot] = []

    private struct Dot {
        let x: Double      // 0..1
        let y: Double      // 0..1
        let alpha: Double
        let size: Double   // points
    }

    var body: some View {
        Canvas { ctx, size in
            for d in dots {
                let rect = CGRect(
                    x: d.x * size.width,
                    y: d.y * size.height,
                    width: d.size,
                    height: d.size
                )
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(d.alpha * intensity))
                )
            }
        }
        .onAppear {
            if dots.isEmpty {
                dots = (0..<600).map { _ in
                    Dot(
                        x: Double.random(in: 0...1),
                        y: Double.random(in: 0...1),
                        alpha: Double.random(in: 0.012...0.038),
                        size: Double.random(in: 0.6...1.4)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

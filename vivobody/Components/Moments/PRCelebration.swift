//
//  PRCelebration.swift
//  vivobody
//
//  Personal-record moment. The app briefly mints a glass medallion
//  for the lifter — a tactile, glowing coin floating in front of a
//  dimmed world — then quietly hands the screen back. Same haptic
//  choreography as before (swell → slam → soft breath); the staging
//  is what changed: instead of expanding rings on a dim screen,
//  there's a single object you've earned.
//
//  Visual language follows the project's Liquid Glass system:
//    • Warm orange (Tint.primary) as the only accent.
//    • Circle medallion uses .glassEffect for that real-material feel.
//    • Specular sweep crosses the medallion once on entrance, like
//      light catching a polished surface.
//    • Sentence-case typography in rounded weights — no tracked caps.
//
//  Use:
//      content
//          .overlay {
//              PRCelebration(
//                  isPresented: $show,
//                  title: "Personal record",
//                  value: "225",
//                  unit: "lb",
//                  detail: "Bench press · 1RM"
//              )
//          }
//

import SwiftUI

struct PRCelebration: View {
    @Binding var isPresented: Bool
    let title: String
    let value: String
    var unit: String? = nil
    var detail: String? = nil

    @State private var backdropVisible: Bool = false
    @State private var medallionScale: CGFloat = 0.2
    @State private var medallionOpacity: Double = 0
    @State private var titleVisible: Bool = false
    @State private var valueScale: CGFloat = 0.55
    @State private var valueVisible: Bool = false
    @State private var detailVisible: Bool = false
    @State private var promptVisible: Bool = false
    @State private var breathing: CGFloat = 1.0
    @State private var sweepProgress: CGFloat = -1.2
    @State private var sparksActive: Bool = false
    @State private var isDismissing: Bool = false

    private let medallionSize: CGFloat = 280

    var body: some View {
        if isPresented {
            ZStack {
                backdrop
                sparks
                medallion
                VStack {
                    Spacer()
                    prompt
                        .padding(.bottom, 64)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            // Tap (not swipe) to dismiss — claims every gesture so
            // the celebration is its own modal moment.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let drift = max(
                            abs(value.translation.width),
                            abs(value.translation.height)
                        )
                        if drift < 10 { dismiss() }
                    }
            )
            .onAppear { startSequence() }
            .transition(.opacity)
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Color.black
                .opacity(backdropVisible ? 0.94 : 0)

            RadialGradient(
                colors: [
                    Tint.primary.opacity(0.20),
                    Tint.primary.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 460
            )
            .opacity(backdropVisible ? 1 : 0)

            // Vignette pulling the screen edges darker so the
            // medallion floats in a pool of light.
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.55)],
                center: .center,
                startRadius: 280,
                endRadius: 560
            )
            .opacity(backdropVisible ? 1 : 0)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            // Outer halo glow — the "this is special" wash.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tint.primary.opacity(0.55),
                            Tint.primary.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .blur(radius: 14)
                .opacity(medallionOpacity)

            // The coin itself.
            ZStack {
                // Soft dark backing so the glass reads against the
                // warm wash behind it.
                Circle()
                    .fill(Color.black.opacity(0.55))

                // Liquid Glass body.
                Circle()
                    .glassEffect(.regular, in: Circle())

                // Warm radial light from upper-left — gives the
                // coin a directional shape (top-left key light).
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Tint.primary.opacity(0.35),
                                Tint.primary.opacity(0.10),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.28, y: 0.22),
                            startRadius: 8,
                            endRadius: 220
                        )
                    )

                // Rim — angular gradient stroke that simulates
                // a polished metal edge catching light from above.
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Tint.primary.opacity(0.95),
                                Color.white.opacity(0.85),
                                Tint.primary.opacity(0.30),
                                Color.black.opacity(0.45),
                                Tint.primary.opacity(0.55),
                                Tint.primary.opacity(0.95)
                            ],
                            center: .center,
                            angle: .degrees(-90)
                        ),
                        lineWidth: 1.4
                    )

                // Inner edge — a soft inset highlight so the
                // surface reads as concave (the number sits in
                // the bowl of the coin).
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
                    .padding(6)

                // Hero content.
                valueStack
                    .padding(.horizontal, 18)

                // Specular sweep — a thin diagonal band of light
                // that crosses the medallion once on entrance.
                specularSweep
            }
            .frame(width: medallionSize, height: medallionSize)
            .clipShape(Circle())
            .shadow(color: Tint.primary.opacity(0.55), radius: 50, y: 0)
            .shadow(color: Tint.primary.opacity(0.30), radius: 110, y: 0)
            .shadow(color: Color.black.opacity(0.55), radius: 24, y: 14)
            .scaleEffect(medallionScale * breathing)
            .opacity(medallionOpacity)
        }
    }

    private var specularSweep: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.55),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: w * 0.55)
            .rotationEffect(.degrees(22))
            .offset(x: w * sweepProgress)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Value stack (inside the medallion)

    private var valueStack: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Tint.primary)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : -6)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .shadow(color: Tint.primary.opacity(0.65), radius: 18)
                    .shadow(color: Tint.primary.opacity(0.30), radius: 44)
                if let unit {
                    Text(unit)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.bottom, 10)
                }
            }
            .scaleEffect(valueScale)
            .opacity(valueVisible ? 1 : 0)

            if let detail {
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                    .opacity(detailVisible ? 1 : 0)
                    .offset(y: detailVisible ? 0 : 6)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Sparks

    /// Drifting embers that rise from below the medallion. Each
    /// spark has its own seeded x/delay/scale so the field feels
    /// organic rather than mechanical.
    private var sparks: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { i in
                Spark(
                    seed: i,
                    active: sparksActive
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Prompt

    private var prompt: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Tint.primary.opacity(0.85))
                .frame(width: 5, height: 5)
                .scaleEffect(breathing)
            Text("Tap to continue")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .opacity(promptVisible ? 1 : 0)
    }

    // MARK: - Choreography

    private func startSequence() {
        Task { @MainActor in
            Haptics.swell()

            withAnimation(.easeOut(duration: 0.32)) {
                backdropVisible = true
            }

            // Medallion swells in with a slight overshoot — it lands
            // with weight, like a thrown coin settling.
            withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) {
                medallionScale = 1.0
                medallionOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                titleVisible = true
            }

            try? await Task.sleep(for: .milliseconds(120))
            Haptics.slam()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                valueScale = 1.0
                valueVisible = true
            }

            // Specular sweep — a single light pass across the coin.
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeInOut(duration: 0.85)) {
                sweepProgress = 1.2
            }

            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                detailVisible = true
            }

            try? await Task.sleep(for: .milliseconds(80))
            sparksActive = true

            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.5)) {
                promptVisible = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = 1.02
            }
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        Haptics.soft()

        withAnimation(.easeIn(duration: 0.28)) {
            backdropVisible = false
            medallionOpacity = 0
            medallionScale = 0.85
            titleVisible = false
            valueVisible = false
            detailVisible = false
            promptVisible = false
            sparksActive = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            isPresented = false
            // Reset for next presentation.
            medallionScale = 0.2
            valueScale = 0.55
            sweepProgress = -1.2
            breathing = 1.0
            isDismissing = false
        }
    }
}

// MARK: - Spark

/// A single drifting ember. Floats up, fades, then teleports back to
/// the bottom and repeats — each spark seeded with its own offset and
/// duration so the field looks alive.
private struct Spark: View {
    let seed: Int
    let active: Bool

    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 0

    private var params: (xOffset: CGFloat, delay: Double, duration: Double, size: CGFloat) {
        // Deterministic pseudo-random per seed so layout is stable
        // across redraws but feels random.
        var rng = SeededRandom(seed: seed)
        let x: CGFloat    = rng.nextCG(in: -130...130)
        let delay         = rng.next(in: 0...2.2)
        let duration      = rng.next(in: 3.4...5.2)
        let size: CGFloat = rng.nextCG(in: 2.2...4.6)
        return (x, delay, duration, size)
    }

    var body: some View {
        Circle()
            .fill(Tint.primary)
            .frame(width: params.size, height: params.size)
            .shadow(color: Tint.primary.opacity(0.85), radius: 6)
            .offset(x: params.xOffset, y: 120 - rise)
            .opacity(opacity)
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    let p = params
                    withAnimation(
                        .easeOut(duration: p.duration)
                        .delay(p.delay)
                        .repeatForever(autoreverses: false)
                    ) {
                        rise = 360
                    }
                    withAnimation(
                        .easeInOut(duration: p.duration)
                        .delay(p.delay)
                        .repeatForever(autoreverses: false)
                    ) {
                        opacity = 0
                    }
                    // Kick the opacity up at the start of each cycle
                    // by using a slight delay before the fade.
                    withAnimation(.easeIn(duration: 0.4).delay(p.delay)) {
                        opacity = 0.85
                    }
                } else {
                    rise = 0
                    opacity = 0
                }
            }
    }
}

// MARK: - Frozen preview helper

/// A non-animated version of `PRCelebration` that renders the
/// medallion in its post-entrance, steady-state form. Used only by
/// the Xcode Preview snapshot tooling so we can inspect the resting
/// composition without waiting for the choreography to play.
struct PRCelebrationFrozen: View {
    let title: String
    let value: String
    var unit: String? = nil
    var detail: String? = nil

    private let medallionSize: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()

            RadialGradient(
                colors: [
                    Tint.primary.opacity(0.20),
                    Tint.primary.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 460
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.55)],
                center: .center,
                startRadius: 280,
                endRadius: 560
            )
            .ignoresSafeArea()

            // Halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tint.primary.opacity(0.55),
                            Tint.primary.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .blur(radius: 14)

            // Coin
            ZStack {
                Circle().fill(Color.black.opacity(0.55))
                Circle().glassEffect(.regular, in: Circle())
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Tint.primary.opacity(0.35),
                                Tint.primary.opacity(0.10),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.28, y: 0.22),
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Tint.primary.opacity(0.95),
                                Color.white.opacity(0.85),
                                Tint.primary.opacity(0.30),
                                Color.black.opacity(0.45),
                                Tint.primary.opacity(0.55),
                                Tint.primary.opacity(0.95)
                            ],
                            center: .center,
                            angle: .degrees(-90)
                        ),
                        lineWidth: 1.4
                    )
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
                    .padding(6)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tint.primary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(value)
                            .font(.system(size: 84, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .shadow(color: Tint.primary.opacity(0.65), radius: 18)
                            .shadow(color: Tint.primary.opacity(0.30), radius: 44)
                        if let unit {
                            Text(unit)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(.bottom, 10)
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(width: medallionSize, height: medallionSize)
            .clipShape(Circle())
            .shadow(color: Tint.primary.opacity(0.55), radius: 50)
            .shadow(color: Tint.primary.opacity(0.30), radius: 110)
            .shadow(color: Color.black.opacity(0.55), radius: 24, y: 14)

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(Tint.primary.opacity(0.85)).frame(width: 5, height: 5)
                    Text("Tap to continue")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.bottom, 64)
            }
        }
    }
}

/// Tiny seeded RNG so each spark gets stable randomness.
private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Splitmix-ish step so adjacent seeds produce uncorrelated values.
        self.state = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15 &+ 0xBF58_476D_1CE4_E5B9
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let v = Double(state >> 11) / Double(UInt64(1) << 53)
        return range.lowerBound + v * (range.upperBound - range.lowerBound)
    }

    mutating func nextCG(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(next(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
}

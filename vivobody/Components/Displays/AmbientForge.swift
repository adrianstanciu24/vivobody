//
//  AmbientForge.swift
//  vivobody
//
//  The living atmosphere behind a tab. The screen reads as the matte
//  black faceplate of a powered-on instrument, and like real hardware
//  the light never washes across the faceplate — it leaks at the seams.
//  Heat rises from the electronics along the bottom edge as a low ember
//  bleed with slow convection hot spots drifting through it, and a much
//  fainter trace escapes at the top seam. The body of the screen stays
//  pure black so content sits on darkness, always.
//
//  It is deliberately data-driven: `warmth` comes from streak + recency,
//  so the glow always *means* something rather than being decorative
//  wash — the same discipline the single accent follows everywhere else.
//  Train, and the seam runs hotter and creeps further in; let days pass,
//  and it cools to a thin idle line — but it never goes out. Drawn in
//  one Canvas for cost, and honors Reduce Motion by holding still at
//  the current temperature.
//

import VivoKit
import SwiftUI
import SwiftData

struct AmbientForge: View {
    /// 0 = cold idle ember, 1 = forge running hot. Eased internally so
    /// changes (e.g. archiving a workout) glide rather than jump.
    var warmth: Double

    /// Overall brightness multiplier. Tabs run near 1.0; pushed detail
    /// screens dial the seam down so it carries through without ever
    /// competing with dense copy.
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var fromWarmth: Double = 0
    @State private var toWarmth: Double = 0
    @State private var changeAt: TimeInterval = 0
    @State private var didIgnite = false

    /// How long a temperature change (including the first ignition from
    /// cold) takes to glide into place.
    private let igniteDuration: TimeInterval = 1.6

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    draw(&context, size: size, time: 0, warmth: clampedTarget, animated: false)
                }
            } else {
                // 30fps is plenty for a slow glow and halves the cost of
                // a full-screen continuously-redrawn Canvas.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        draw(&context, size: size, time: t, warmth: easedWarmth(at: t), animated: true)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !didIgnite else { return }
            didIgnite = true
            // Ignite from cold the first time the screen is shown — the
            // forge lighting up as you arrive.
            fromWarmth = 0
            toWarmth = warmth
            changeAt = Date().timeIntervalSinceReferenceDate
        }
        .onChange(of: warmth) { _, new in
            fromWarmth = toWarmth
            toWarmth = new
            changeAt = Date().timeIntervalSinceReferenceDate
        }
    }

    private var clampedTarget: Double { min(1, max(0, warmth)) }

    /// Smoothstep glide from the previous temperature to the new one.
    private func easedWarmth(at t: TimeInterval) -> Double {
        let p = min(1, max(0, (t - changeAt) / igniteDuration))
        let eased = p * p * (3 - 2 * p)
        return fromWarmth + (toWarmth - fromWarmth) * eased
    }

    // MARK: - Drawing

    private func draw(
        _ context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        warmth w: Double,
        animated: Bool
    ) {
        let light = colorScheme != .dark
        // Additive ember glows on a black stage; on a light page that
        // same add-blend clips to white, so light mode lays down a warm
        // amber wash with normal blending instead.
        context.blendMode = light ? .normal : .plusLighter
        // Additive-on-black shows even a dim ember, but a normal-blend
        // tint on a near-white page needs far more opacity to register.
        let alphaScale = light ? 1.35 : 1.0
        let tau = 2 * Double.pi

        // Dim and deep when cold, brighter when hot — but capped low.
        // The seam is heat escaping a chassis, never a light show; the
        // faceplate itself must stay dark at any temperature.
        let temperature = 0.30 + 0.70 * w

        // One slow breath shared by the whole seam plus a faint faster
        // shimmer riding on top, so it reads as live convection.
        let breath = animated ? (sin(time * tau / 6.2) + 1) / 2 : 0.5
        let shimmer = animated ? (sin(time * tau / 2.7 + 1.3) + 1) / 2 : 0.5
        let pulse = 0.80 + 0.16 * breath + 0.04 * shimmer

        // Bottom seam: the dominant leak. Heat rises off the electronics
        // under the tab bar; warmth sets how far it creeps up the plate.
        // The floating tab chrome owns roughly the bottom 11% of the
        // screen, so the creep starts past it — otherwise the whole seam
        // hides behind glass and the temperature stops reading at all.
        let bottomCreep = size.height * (0.14 + 0.13 * w)
        let bottomPeak = (0.14 + 0.16 * w) * pulse * intensity * alphaScale
        fillSeam(
            &context,
            rect: CGRect(x: 0, y: size.height - bottomCreep, width: size.width, height: bottomCreep),
            from: CGPoint(x: size.width / 2, y: size.height),
            to: CGPoint(x: size.width / 2, y: size.height - bottomCreep),
            peak: bottomPeak, warmth: w, light: light
        )

        // Convection hot spots: small mounds of light drifting along the
        // bottom seam. Centered below the edge so only their crowns show.
        for spot in Self.spots {
            let drift = animated ? CGFloat(sin(time * tau / spot.driftSeconds + spot.phase)) * spot.drift : 0
            let sway = animated ? (sin(time * tau / spot.breathSeconds + spot.phase) + 1) / 2 : 0.5
            let radius = size.width * spot.radius * (1 + 0.08 * CGFloat(sway))
            let center = CGPoint(
                x: size.width * spot.x + drift,
                y: size.height + radius * 0.52
            )
            let peak = spot.peak * temperature * (0.72 + 0.28 * sway) * intensity * alphaScale
            let gradient = Gradient(stops: [
                .init(color: ember(w, peak, light: light), location: 0.0),
                .init(color: ember(w, peak * 0.4, light: light), location: 0.5),
                .init(color: ember(w, 0.0, light: light), location: 1.0),
            ])
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
            )
        }

        // Top seam: a much fainter trace under the nav chrome, just
        // enough to say the whole chassis is warm, not only the base.
        let topCreep = size.height * (0.04 + 0.04 * w)
        let topPeak = (0.05 + 0.06 * w) * pulse * intensity * alphaScale
        fillSeam(
            &context,
            rect: CGRect(x: 0, y: 0, width: size.width, height: topCreep),
            from: CGPoint(x: size.width / 2, y: 0),
            to: CGPoint(x: size.width / 2, y: topCreep),
            peak: topPeak, warmth: w, light: light
        )
    }

    /// A linear ember bleed from a screen edge toward black — the light
    /// escaping a chassis seam. Falls off fast so it stays a thin leak.
    private func fillSeam(
        _ context: inout GraphicsContext,
        rect: CGRect,
        from: CGPoint,
        to: CGPoint,
        peak: Double,
        warmth w: Double,
        light: Bool
    ) {
        let gradient = Gradient(stops: [
            .init(color: ember(w, peak, light: light), location: 0.0),
            .init(color: ember(w, peak * 0.42, light: light), location: 0.45),
            .init(color: ember(w, 0.0, light: light), location: 1.0),
        ])
        context.fill(
            Path(rect),
            with: .linearGradient(gradient, startPoint: from, endPoint: to)
        )
    }

    /// Deep ember → hot orange interpolation. Both endpoints sit on the
    /// app's single orange accent family, so the forge never introduces a
    /// competing hue. Light mode swaps to a warm amber that deepens from
    /// a pale peach (idle) toward a richer orange (hot) — more saturated
    /// than the gray surface so a normal-blend wash reads as warmth
    /// rather than glare.
    private func ember(_ w: Double, _ opacity: Double, light: Bool) -> Color {
        if light {
            let g = 0.70 - 0.16 * w
            let b = 0.46 - 0.24 * w
            return Color(.sRGB, red: 1.0, green: g, blue: b, opacity: opacity)
        }
        let r = 0.85 + 0.15 * w
        let g = 0.26 + 0.19 * w
        return Color(.sRGB, red: r, green: g, blue: 0.0, opacity: opacity)
    }

    // MARK: - Seam layout

    private struct SeamSpot {
        var x: CGFloat            // 0..1 of width along the bottom seam
        var radius: CGFloat       // fraction of the width
        var peak: Double          // base opacity at full heat
        var drift: CGFloat        // horizontal wander in points
        var driftSeconds: Double
        var breathSeconds: Double // slow swell period
        var phase: Double
    }

    /// Three hot spots spread along the bottom seam, like uneven coals
    /// behind a vent. Periods are desynced so they never pulse in unison
    /// and the seam reads as organic convection rather than a strip light.
    private static let spots: [SeamSpot] = [
        SeamSpot(x: 0.22, radius: 0.42, peak: 0.26, drift: 46,
                 driftSeconds: 21, breathSeconds: 5.1, phase: 0.0),
        SeamSpot(x: 0.60, radius: 0.50, peak: 0.30, drift: 54,
                 driftSeconds: 27, breathSeconds: 6.0, phase: 2.1),
        SeamSpot(x: 0.88, radius: 0.36, peak: 0.20, drift: 40,
                 driftSeconds: 18, breathSeconds: 4.4, phase: 3.9),
    ]
}

// MARK: - Shared warmth signal

extension Array where Element == WorkoutSession {
    /// Warmth (0–1) for the ambient forge: hottest right after training
    /// and while a streak is alive, cooling toward a low idle glow as
    /// days pass. Floored well above zero — the instrument is always on.
    /// The single source of truth so every tab burns at one temperature.
    var forgeWarmth: Double {
        let streakBoost = Swift.min(1.0, Double(forgeStreakDays) / 7.0)
        let recency: Double
        if let days = daysSinceForgeWorkout {
            recency = Swift.max(0.0, 1.0 - Double(days) / 5.0)
        } else {
            recency = 0.0
        }
        let trainedTodayBoost = daysSinceForgeWorkout == 0 ? 0.15 : 0.0
        return Swift.min(1.0, Swift.max(0.34, 0.5 * recency + 0.5 * streakBoost + trainedTodayBoost))
    }

    /// Consecutive training days counting back from today — forgiving of
    /// an unworked morning by starting from yesterday when needed.
    private var forgeStreakDays: Int {
        let cal = Calendar.current
        let days = Set(map { cal.startOfDay(for: $0.completedAt ?? $0.startedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = cal.startOfDay(for: Date())
        if !days.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    /// Whole days since the most recent session, or nil when empty.
    private var daysSinceForgeWorkout: Int? {
        let cal = Calendar.current
        let dates = map { $0.completedAt ?? $0.startedAt }
        guard let latest = dates.max() else { return nil }
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: latest),
            to: cal.startOfDay(for: Date())
        ).day
    }
}

// MARK: - Shared backdrop

extension View {
    /// The primary-tab backdrop: deep black with the data-driven seam
    /// glow behind the content. Mirrors `screenBackground()` but swaps
    /// the flat fill for the living forge, so Today's siblings share one
    /// atmosphere. Content renders untouched on top.
    ///
    /// Plain `ignoresSafeArea()` (no `backgroundExtensionEffect()`):
    /// the seam is anchored to the physical screen edges, so the canvas
    /// must genuinely reach them. The extension effect clips its view to
    /// the safe area and mirrors the edge into the insets, which would
    /// replace the hot bottom seam with a blurred copy of the dim tail.
    func forgeBackground(intensity: Double = 0.9) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ForgeBackground(intensity: intensity)
                    .ignoresSafeArea()
            )
    }

    /// The backdrop for a screen pushed off a forge-lit tab (session
    /// detail, exercise detail, the Me sub-screens, Settings). It's the
    /// same living forge, dialed well down so the ember warmth carries
    /// through the push instead of dropping to flat black — the child
    /// stays tethered to the tab it came from — while staying quiet
    /// enough not to compete with dense detail copy. Modal sheets and
    /// the focused workout deliberately keep the flat surface instead.
    func detailForgeBackground() -> some View {
        forgeBackground(intensity: 0.45)
    }
}

/// Hosts the forge's data dependency so call sites stay a single
/// modifier: it queries the archived sessions itself and renders the
/// ember field at the warmth they imply, over the standard black.
private struct ForgeBackground: View {
    var intensity: Double = 0.9

    @Query(filter: #Predicate<WorkoutSession> { $0.completedAt != nil })
    private var sessions: [WorkoutSession]

    var body: some View {
        ZStack {
            Surface.background
            // AmbientForge adapts its own compositing per appearance —
            // an additive ember on the black stage, a soft warm amber
            // wash on the light surface — so it renders in both.
            AmbientForge(warmth: sessions.forgeWarmth, intensity: intensity)
        }
    }
}

#Preview("Ambient forge") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientForge(warmth: 0.9)
        VStack {
            Text("Forge")
                .font(Typography.display)
                .foregroundStyle(.white)
        }
    }
    .preferredColorScheme(.dark)
}

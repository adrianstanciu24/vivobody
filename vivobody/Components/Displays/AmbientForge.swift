//
//  AmbientForge.swift
//  vivobody
//
//  The living atmosphere behind a tab. The design system describes the
//  accent as "molten / high-energy" — the forge makes that literal: a
//  slow field of ember light that breathes behind the content and burns
//  at a temperature set by your training. Train, and the forge runs hot
//  and bright; let days pass, and it cools to a low idle glow — but it
//  never goes out, because the instrument is always on.
//
//  It is deliberately data-driven: `warmth` comes from streak + recency,
//  so the glow always *means* something rather than being decorative
//  wash — the same discipline the single accent follows everywhere else.
//  Drawn in one Canvas of additive radial lobes for cost; the field
//  parallaxes slightly slower than the content for depth, and honors
//  Reduce Motion by holding still at the current temperature.
//

import SwiftUI
import SwiftData

struct AmbientForge: View {
    /// 0 = cold idle ember, 1 = forge running hot. Eased internally so
    /// changes (e.g. archiving a workout) glide rather than jump.
    var warmth: Double

    /// Overall brightness multiplier. Today (figure hero) burns at the
    /// full 1.0; the text-dense sibling tabs dial this down a touch so
    /// the ember never competes with copy.
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
        // tint on a near-white page needs far more opacity to register,
        // so scale the light wash up well past 1.0. The radial falloff
        // keeps it a halo rather than a solid block even when the peak
        // clamps near opaque at full heat.
        let alphaScale = light ? 1.35 : 1.0
        let tau = 2 * Double.pi
        let maxDim = max(size.width, size.height)

        for lobe in Self.lobes {
            // Slow organic wander + a faster shimmer on top, so the field
            // reads as live convection rather than a static tint.
            let driftX = animated ? CGFloat(sin(time * tau / lobe.driftSecondsX + lobe.phase)) * lobe.driftX : 0
            let driftY = animated ? CGFloat(cos(time * tau / lobe.driftSecondsY + lobe.phase)) * lobe.driftY : 0
            let breath = animated ? (sin(time * tau / lobe.breathSeconds + lobe.phase) + 1) / 2 : 0.5
            let flicker = animated ? (sin(time * tau / lobe.flickerSeconds + lobe.phase * 2.3) + 1) / 2 : 0.5

            let center = CGPoint(
                x: size.width * lobe.x + driftX,
                y: size.height * lobe.y + driftY
            )

            // Visible breathing: ~26% brightness swing + a 10% size swell,
            // with a small flicker riding on top so it never looks frozen.
            let pulse = 0.66 + 0.26 * breath + 0.08 * flicker
            let radius = maxDim * lobe.radius * (1 + 0.10 * CGFloat(breath) + 0.03 * CGFloat(flicker))

            // Temperature scales brightness: dim & deep when cold, bright
            // & orange when hot.
            let temperature = 0.34 + 0.66 * w
            let peak = lobe.peak * temperature * pulse * intensity * alphaScale

            let gradient = Gradient(stops: [
                .init(color: ember(w, peak, light: light), location: 0.0),
                .init(color: ember(w, peak * 0.45, light: light), location: 0.4),
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

    // MARK: - Lobe layout

    private struct Lobe {
        var x: CGFloat              // 0..1 of width
        var y: CGFloat              // 0..1 of height
        var radius: CGFloat         // fraction of the max dimension
        var peak: Double            // base opacity at full heat
        var driftX: CGFloat
        var driftY: CGFloat
        var driftSecondsX: Double
        var driftSecondsY: Double
        var breathSeconds: Double   // slow swell period
        var flickerSeconds: Double  // faster shimmer period
        var phase: Double
    }

    /// Three lobes: a dominant glow up in the hero zone (behind the
    /// figure), a warm pool low-left under the start control, and a faint
    /// mid-right counterlight. The text-heavy middle band is left
    /// comparatively dark so copy stays legible. Periods are desynced so
    /// the three never pulse in unison — the field reads as organic.
    private static let lobes: [Lobe] = [
        // The hero halo: a dominant, focused glow directly behind the figure.
        // Burns brighter and tighter to act as a studio backlight.
        Lobe(x: 0.50, y: 0.28, radius: 0.75, peak: 0.75,
             driftX: 48, driftY: 40, driftSecondsX: 19, driftSecondsY: 26,
             breathSeconds: 4.6, flickerSeconds: 2.3, phase: 0.0),
        Lobe(x: 0.18, y: 0.84, radius: 0.58, peak: 0.25,
             driftX: 40, driftY: 34, driftSecondsX: 23, driftSecondsY: 18,
             breathSeconds: 5.4, flickerSeconds: 2.9, phase: 1.7),
        Lobe(x: 0.84, y: 0.52, radius: 0.46, peak: 0.15,
             driftX: 34, driftY: 46, driftSecondsX: 27, driftSecondsY: 21,
             breathSeconds: 6.1, flickerSeconds: 3.4, phase: 3.1),
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
    /// The primary-tab backdrop: deep black with the data-driven ember
    /// field behind the content. Mirrors `screenBackground()` but swaps
    /// the flat fill for the living forge, so Today's siblings share one
    /// atmosphere. Content renders untouched on top.
    ///
    /// `backgroundExtensionEffect()` mirrors the forge into the safe-
    /// area insets (navigation bar, tab bar) so the ember glow bleeds
    /// seamlessly under translucent chrome instead of terminating at a
    /// hard edge.
    func forgeBackground(intensity: Double = 0.9) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ForgeBackground(intensity: intensity)
                    .ignoresSafeArea()
                    .backgroundExtensionEffect()
            )
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

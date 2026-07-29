//
//  CadenceDot.swift
//  vivobody
//
//  One day of showing up, drawn as an ember. Shared by History's
//  week cadence strip and Today's two-week ConsistencyStrip so a
//  trained day looks identical wherever the app plots attendance —
//  it lives here rather than beside either screen because both own it.
//
//  Use:
//      CadenceDot(isWorkout: true, isToday: false, isPast: true, isPR: false)
//

import VivoKit
import SwiftUI

/// A single cadence dot, drawn flat like StreakCalendar's DayDot: a
/// trained day is a solid ember disc, a past rest day a full-size
/// gray disc, a future rest day only a faint ring. Today always
/// wears a ring — orange while it's still open, a quiet bright rim
/// once trained. PR days gently pulsate on top, a scale breath plus
/// a brightening glow, matching the forge's living-motion vocabulary.
/// `effort` (0...1, default 1) scales the trained disc's diameter so
/// a heavy day burns bigger than a light one; callers without effort
/// data leave it at 1 and every trained day renders full size. The
/// fixed frame never moves, so mixed sizes don't jitter the row.
/// Reduce Motion users see a static dot.
struct CadenceDot: View {
    let isWorkout: Bool
    let isToday: Bool
    let isPast: Bool
    let isPR: Bool
    var effort: Double = 1.0

    static let size: CGFloat = 34

    /// Effort clamped to the unit interval.
    private var t: Double { min(max(effort, 0), 1) }

    /// Ember diameter for the day's effort: the lightest trained day
    /// still renders at 62% so the ember never reads as unlit.
    private var emberDiameter: CGFloat {
        Self.size * (0.62 + 0.38 * t)
    }

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var pulse = false

    var shouldPulse: Bool { isPR && !reduceMotion }

    var body: some View {
        ZStack {
            if isWorkout {
                Circle()
                    .fill(Tint.primary)
                    .frame(width: emberDiameter, height: emberDiameter)
            } else if isPast {
                // Full grid size: a missed day is part of the record,
                // not a hole in it — it holds the same circle a trained
                // day would, just unlit.
                Circle()
                    .fill(Surface.edge)
            }
            if showsRing {
                Circle()
                    .stroke(ringColor, lineWidth: isToday ? 1.5 : 1)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .scaleEffect(shouldPulse ? (pulse ? 1.06 : 1.0) : 1.0)
        .shadow(
            color: shouldPulse ? Tint.primary.opacity(pulse ? 0.35 : 0) : .clear,
            radius: pulse ? 8 : 0
        )
        .onAppear {
            guard shouldPulse else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    /// Rings mark days that are still open: today always wears one,
    /// future rest days keep a faint one. Trained days (gradient does
    /// the work) and past rest days (the pip) go ringless.
    var showsRing: Bool {
        isToday || (!isWorkout && !isPast)
    }

    /// An empty today wears the in-progress orange ring; a trained
    /// today gets a quiet bright rim; future rest days stay faint.
    var ringColor: Color {
        if isToday && !isWorkout { return Tint.inProgress }
        if isToday { return Ink.primary.opacity(Opacity.medium) }
        return Surface.edge.opacity(0.5)
    }
}

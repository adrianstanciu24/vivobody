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
//      CadenceDot(isWorkout: true, isPR: false)
//      CadenceDot(isWorkout: true, isPR: true, ignitionOrder: 9)
//

import VivoKit
import SwiftUI

/// A single cadence dot, in one of three states and no more:
///
///   • done — a flat orange disc wearing a thin orange ring, a soft
///     orange glow behind it.
///   • done with PR — the same disc, its ring slowly pulsing.
///   • not done — a quiet dark gray coal wearing a faint gray ring,
///     full size like the rest: a missed day is part of the record,
///     not a hole in it.
///
/// Every disc renders at the same full size and every day wears the
/// outer ring; only the colors and the PR pulse change. Today and
/// future days get no special treatment — a day is done or it isn't.
///
/// Ignition: when `ignitionOrder` is set (the two-week strip passes
/// it, oldest = 0), a trained ember's light arrives oldest-first
/// with a brightness overshoot that decays to rest — LivingMotion's
/// power-on vocabulary at dot scale. Not-done discs render
/// immediately; only the fire arrives staggered. A nil order renders
/// the ember already lit (History's week cadence). Reduce Motion
/// users see a static dot throughout.
struct CadenceDot: View {
    let isWorkout: Bool
    let isPR: Bool
    /// Position in the strip's ignition sequence, oldest = 0. nil
    /// renders the ember already lit.
    var ignitionOrder: Int? = nil

    /// Small enough that seven columns breathe inside the card; the
    /// ring rides 7pt beyond the disc.
    static let size: CGFloat = 26

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ignition entrance: the ember's light has arrived.
    @State private var ignited = false
    /// Brightness overshoot decaying after ignition.
    @State private var flash = false
    /// The PR glow ring's slow pulse.
    @State private var pulsing = false

    private var shouldIgnite: Bool {
        isWorkout && ignitionOrder != nil && !reduceMotion
    }

    private var shouldPulse: Bool {
        isWorkout && isPR && !reduceMotion
    }

    private var fill: Color {
        isWorkout ? Tint.primary : Surface.edge.opacity(0.6)
    }

    /// The soft halo behind trained embers; unlit coals go without.
    private var glowColor: Color {
        isWorkout ? Tint.primary.opacity(0.45) : .clear
    }

    private var glowRadius: CGFloat {
        isWorkout ? 6 : 0
    }

    /// The outer ring every day wears: orange around embers, a quiet
    /// gray around unlit coals.
    private var ringColor: Color {
        isWorkout ? Tint.primary : Surface.edgeBright
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: Self.size, height: Self.size)
                .shadow(color: glowColor, radius: glowRadius)
            Circle()
                .stroke(ringColor, lineWidth: 1.5)
                .frame(width: Self.size + 7, height: Self.size + 7)
                .scaleEffect(shouldPulse && pulsing ? 1.08 : 1)
                .opacity(shouldPulse && pulsing ? 0.55 : 1)
        }
        // Fixed layout frame: the ring draws past it without moving
        // the row.
        .frame(width: Self.size, height: Self.size)
        .opacity(ignited ? 1 : 0)
        .brightness(flash ? 0.3 : 0)
        .onAppear(perform: appear)
    }

    private func appear() {
        if shouldPulse, !pulsing {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        guard !ignited else { return }
        guard shouldIgnite else {
            ignited = true
            return
        }
        // Oldest ember first: the strip catches fire left to right,
        // top row to bottom, today last.
        let delay = 0.1 + Double(ignitionOrder ?? 0) * 0.045
        withAnimation(.easeOut(duration: 0.18).delay(delay)) {
            ignited = true
            flash = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(delay + 0.18)) {
            flash = false
        }
    }
}

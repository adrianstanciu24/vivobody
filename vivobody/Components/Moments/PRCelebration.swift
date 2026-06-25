//
//  PRCelebration.swift
//  vivobody
//
//  Personal-record moment. This is the one place the *complete*
//  accent (gold) gets to take the whole screen — you earned it.
//
//  Form (instrument language):
//    • Full-bleed black. No medallion, no glass, no sparks, no bloom.
//    • The value is the hero: a huge monospaced GOLD numeral.
//    • A tiny "Personal record" kicker above, a mono detail line below,
//      and a single gold hairline that draws in under the number.
//
//  The "moment" comes from motion + haptics, not ornament — the same
//  choreography as before: swell on entrance → the number slams in
//  with overshoot (Haptics.slam) → detail settles → a calm breath on
//  the prompt. Tap anywhere to continue.
//
//  Use:
//      content.overlay {
//          PRCelebration(
//              isPresented: $show,
//              title: "Personal record",
//              value: "225",
//              unit: "lb",
//              detail: "Bench press · New max"
//          )
//      }
//

import SwiftUI

struct PRCelebration: View {
    @Binding var isPresented: Bool
    let title: String
    let value: String
    var unit: String? = nil
    var detail: String? = nil

    @State private var backdropVisible: Bool = false
    @State private var titleVisible: Bool = false
    @State private var valueScale: CGFloat = 0.55
    @State private var valueVisible: Bool = false
    @State private var underlineProgress: CGFloat = 0
    @State private var detailVisible: Bool = false
    @State private var promptVisible: Bool = false
    @State private var breathing: CGFloat = 1.0
    @State private var isDismissing: Bool = false

    var body: some View {
        if isPresented {
            ZStack {
                Surface.background
                    .opacity(backdropVisible ? 0.96 : 0)
                    .ignoresSafeArea()

                centerStack

                VStack {
                    Spacer()
                    prompt
                        .padding(.bottom, 64)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            // Tap (not swipe) to dismiss — claims every gesture so the
            // celebration is its own modal moment.
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

    // MARK: - Content

    private var centerStack: some View {
        VStack(spacing: Space.md) {
            Text(title)
                .font(Typography.sectionLabel)
                .tracking(0.5)
                .foregroundStyle(Tint.complete)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : -6)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(Typography.bigMetric)
                    .foregroundStyle(Tint.complete)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .shadow(color: Tint.complete.opacity(0.35), radius: 18)
                if let unit {
                    Text(unit)
                        .font(Typography.statValue)
                        .foregroundStyle(Tint.complete.opacity(Opacity.emphasis))
                        .padding(.bottom, 12)
                }
            }
            .scaleEffect(valueScale)
            .opacity(valueVisible ? 1 : 0)

            Capsule()
                .fill(Tint.complete)
                .frame(width: 120 * underlineProgress, height: 3)
                .opacity(valueVisible ? 1 : 0)

            if let detail {
                Text(detail)
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
                    .opacity(detailVisible ? 1 : 0)
                    .offset(y: detailVisible ? 0 : 6)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private var prompt: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Tint.inProgress.opacity(0.85))
                .frame(width: 5, height: 5)
                .scaleEffect(breathing)
            Text("Tap to continue")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
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

            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                titleVisible = true
            }

            // The number lands with weight.
            try? await Task.sleep(for: .milliseconds(120))
            Haptics.slam()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                valueScale = 1.0
                valueVisible = true
            }

            // Gold hairline draws in under the number.
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.easeOut(duration: 0.6)) {
                underlineProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                detailVisible = true
            }

            try? await Task.sleep(for: .milliseconds(780))
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
            titleVisible = false
            valueVisible = false
            detailVisible = false
            promptVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            isPresented = false
            // Reset for next presentation.
            valueScale = 0.55
            underlineProgress = 0
            breathing = 1.0
            isDismissing = false
        }
    }
}

// MARK: - Frozen preview helper

/// A non-animated version that renders the resting, post-entrance
/// composition. Used only by the gallery / Preview snapshot tooling
/// so the steady state can be inspected without the choreography.
struct PRCelebrationFrozen: View {
    let title: String
    let value: String
    var unit: String? = nil
    var detail: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            VStack(spacing: Space.md) {
                Text(title)
                    .font(Typography.sectionLabel)
                    .tracking(0.5)
                    .foregroundStyle(Tint.complete)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value)
                        .font(Typography.bigMetric)
                        .foregroundStyle(Tint.complete)
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .shadow(color: Tint.complete.opacity(0.35), radius: 18)
                    if let unit {
                        Text(unit)
                            .font(Typography.statValue)
                            .foregroundStyle(Tint.complete.opacity(Opacity.emphasis))
                            .padding(.bottom, 12)
                    }
                }

                Capsule()
                    .fill(Tint.complete)
                    .frame(width: 120, height: 3)

                if let detail {
                    Text(detail)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.secondary)
                }
            }
            .padding(.horizontal, Space.gutter)

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(Tint.inProgress.opacity(0.85)).frame(width: 5, height: 5)
                    Text("Tap to continue")
                        .font(Typography.sectionLabel)
                        .foregroundStyle(Ink.tertiary)
                }
                .padding(.bottom, 64)
            }
        }
    }
}

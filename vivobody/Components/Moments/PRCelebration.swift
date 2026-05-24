//
//  PRCelebration.swift
//  vivobody
//
//  The one moment in the app that's allowed to break composure. When a
//  personal record lands, the screen briefly stops being functional and
//  becomes a small ceremony — warm radial light, a stack of expanding
//  rings, the number arriving with weight, a slam at the moment of
//  impact. After that, stillness — a slow breath, a quiet prompt to
//  continue. Tap anywhere to dismiss.
//
//  Design rules:
//  - It must feel *unrepeatable*. No part of the regular flow looks
//    like this. The choreography is reserved for actual PRs.
//  - The number is the hero. Everything else gets out of its way.
//  - Warm gold, not screaming red. Accomplishment, not alarm.
//
//  Use:
//      @State private var show = false
//      content
//          .overlay {
//              PRCelebration(
//                  isPresented: $show,
//                  title: "PERSONAL RECORD",
//                  value: "225",
//                  unit: "lb",
//                  detail: "BENCH PRESS · 1RM"
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

    // Choreography state
    @State private var backdropVisible: Bool = false
    @State private var ringsActive: Bool = false
    @State private var labelVisible: Bool = false
    @State private var valueVisible: Bool = false
    @State private var detailVisible: Bool = false
    @State private var promptVisible: Bool = false
    @State private var breathing: CGFloat = 1.0
    @State private var isDismissing: Bool = false

    private let warmGold = Color(red: 1.0, green: 0.82, blue: 0.45)
    private let warmGlow = Color(red: 1.0, green: 0.78, blue: 0.42)

    var body: some View {
        if isPresented {
            ZStack {
                backdrop
                rings
                valueStack
                VStack {
                    Spacer()
                    prompt
                        .padding(.bottom, 72)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            // The screen says "TAP TO CONTINUE" — make that literal.
            // A DragGesture(minimumDistance: 0) claims every touch in
            // the celebration's bounds, so swipes that would otherwise
            // bubble up to the sheet's drag-to-dismiss (or the pager
            // underneath) get absorbed here and do nothing. Only a
            // touch that lifts within ~10pt of where it started — a
            // tap, by every iOS heuristic — triggers dismissal.
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

    // MARK: - Layers

    private var backdrop: some View {
        ZStack {
            // Base dim
            Color.black
                .opacity(backdropVisible ? 0.92 : 0)

            // Warm wash from center
            RadialGradient(
                colors: [
                    warmGlow.opacity(0.18),
                    Color.clear,
                ],
                center: .center,
                startRadius: 30,
                endRadius: 420
            )
            .opacity(backdropVisible ? 1 : 0)
        }
    }

    private var rings: some View {
        ZStack {
            ForEach(0..<4) { i in
                Circle()
                    .stroke(ringColor(i), lineWidth: ringLineWidth(i))
                    .frame(width: 90, height: 90)
                    .scaleEffect(ringsActive ? 9.5 : 0.05)
                    .opacity(ringsActive ? 0 : ringStartOpacity(i))
                    .animation(
                        .easeOut(duration: 1.15).delay(Double(i) * 0.08),
                        value: ringsActive
                    )
            }
        }
    }

    private var valueStack: some View {
        VStack(spacing: 14) {
            // Label with editorial accent strokes on either side.
            HStack(spacing: 12) {
                accentStroke
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(warmGold)
                accentStroke
            }
            .opacity(labelVisible ? 1 : 0)
            .offset(y: labelVisible ? 0 : 10)

            // The hero: big number + small unit.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 108, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: warmGlow.opacity(0.55), radius: 28, x: 0, y: 0)
                    .shadow(color: warmGlow.opacity(0.30), radius: 60, x: 0, y: 0)
                if let unit {
                    Text(unit)
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 14)
                }
            }
            .scaleEffect(valueVisible ? breathing : 0.55)
            .opacity(valueVisible ? 1 : 0)

            // Detail line.
            if let detail {
                HStack(spacing: 10) {
                    accentStroke
                    Text(detail)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                    accentStroke
                }
                .opacity(detailVisible ? 1 : 0)
                .offset(y: detailVisible ? 0 : -8)
                .padding(.top, 2)
            }
        }
    }

    private var accentStroke: some View {
        Rectangle()
            .fill(warmGold.opacity(0.55))
            .frame(width: 18, height: 1)
    }

    private var prompt: some View {
        Text("TAP TO CONTINUE")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.35))
            .opacity(promptVisible ? 1 : 0)
    }

    // MARK: - Ring styling

    private func ringColor(_ i: Int) -> Color {
        i.isMultiple(of: 2) ? warmGold : Color.white
    }

    private func ringStartOpacity(_ i: Int) -> Double {
        [0.65, 0.45, 0.50, 0.30][i]
    }

    private func ringLineWidth(_ i: Int) -> CGFloat {
        [2.2, 1.6, 1.8, 1.2][i]
    }

    // MARK: - Choreography

    private func startSequence() {
        Task { @MainActor in
            Haptics.swell()

            withAnimation(.easeOut(duration: 0.28)) {
                backdropVisible = true
            }
            withAnimation(.easeOut(duration: 1.1)) {
                ringsActive = true
            }

            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                labelVisible = true
            }

            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                valueVisible = true
            }
            Haptics.slam()

            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                detailVisible = true
            }

            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.5)) {
                promptVisible = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = 1.015
            }
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        Haptics.soft()

        withAnimation(.easeIn(duration: 0.3)) {
            backdropVisible = false
            ringsActive = false
            labelVisible = false
            valueVisible = false
            detailVisible = false
            promptVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            isPresented = false
            // Reset for next presentation
            ringsActive = false
            breathing = 1.0
            isDismissing = false
        }
    }
}

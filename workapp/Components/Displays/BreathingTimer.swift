//
//  BreathingTimer.swift
//  workapp
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

    private let cool = Color(.sRGB, red: 0.42, green: 0.72, blue: 0.96, opacity: 1)
    private let warm = Color(.sRGB, red: 0.98, green: 0.58, blue: 0.20, opacity: 1)

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
                background
                breathLayers(scale: scale, color: color, progress: progress)
                centerContent(remaining: remainingExact)
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

    private var background: some View {
        LinearGradient(
            colors: [Color.black, Color(.sRGB, white: 0.04, opacity: 1), Color.black],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func breathLayers(scale: Double, color: Color, progress: Double) -> some View {
        ZStack {
            // Atmosphere — soft outer halo
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 360, height: 360)
                .scaleEffect(scale * 1.05)
                .blur(radius: 50)

            // Body — filled gradient disc. Self-illuminated orb feel.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: color.opacity(0.55), location: 0.0),
                            .init(color: color.opacity(0.35), location: 0.55),
                            .init(color: color.opacity(0.12), location: 0.92),
                            .init(color: color.opacity(0.00), location: 1.0),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(scale)
                .blendMode(.plusLighter)

            // A second softer disc bloom that lags the breath slightly.
            // Keeps the body from looking flat.
            Circle()
                .fill(color.opacity(0.22))
                .frame(width: 180, height: 180)
                .scaleEffect(scale)
                .blur(radius: 28)

            // Track — the rim that holds the progress marker.
            Circle()
                .stroke(color.opacity(0.30), lineWidth: 4)
                .frame(width: 240, height: 240)
                .scaleEffect(scale)

            // Marker — progress arc traveling along the track.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 240, height: 240)
                .scaleEffect(scale)
        }
    }

    private func centerContent(remaining: TimeInterval) -> some View {
        VStack(spacing: 6) {
            Text(hasFinished ? "GO" : "REST")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.45))

            DigitTicker(
                value: remaining,
                font: .system(size: 64, weight: .bold, design: .rounded),
                color: .white,
                formatter: { time in
                    let total = Int(time.rounded(.up))
                    return String(format: "%d:%02d", total / 60, total % 60)
                }
            )

            Text("of \(formatted(totalDuration))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .opacity(hasFinished ? 0 : 1)
        }
    }

    private var hints: some View {
        VStack {
            // Skip hint at top — appears when dragging DOWN
            hintView(label: "↓  SKIP REST", visibility: hintVisibility(dragOffset, direction: .down))
                .padding(.top, 90)
            Spacer()
            // Extend hint at bottom — appears when dragging UP
            hintView(label: "↑  +30 SEC", visibility: hintVisibility(dragOffset, direction: .up))
                .padding(.bottom, 110)
        }
    }

    private func hintView(label: String, visibility: Double) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white.opacity(visibility))
            .scaleEffect(0.92 + 0.08 * visibility)
    }

    @ViewBuilder
    private var nextSet: some View {
        if let nextSetLabel {
            VStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("NEXT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.35))
                    Text(nextSetLabel)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 40)
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

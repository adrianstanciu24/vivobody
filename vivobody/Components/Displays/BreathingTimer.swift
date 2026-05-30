//
//  BreathingTimer.swift
//  vivobody
//
//  The rest-timer screen. Most of a workout is rest, so this isn't a modal —
//  it's the home base between sets, and the calmest screen in the app.
//
//  Form (instrument language):
//    • Full-bleed black. No orb, no glass, no grain — type and whitespace.
//    • The TIME is the hero: a huge monospaced numeral that owns the screen.
//    • Progress is a single thin hairline bar that depletes — a gauge, not
//      a glowing ring.
//    • One accent: Volt (rest = in-progress; you're between sets). The old
//      cool→orange warm-up is gone; the haptic escalation carries urgency.
//
//  Behaviour (unchanged — sacred):
//    • The numeral breathes gently to set a calming pace; the breath roughly
//      doubles in the final 10s.
//    • At T-3, T-2, T-1 escalating haptics fire (light → medium → heavy);
//      at T-0 a success haptic lands, the breath freezes, "Go" appears.
//    • Pull DOWN past threshold → skip. Pull UP past threshold → +30s.
//      Below threshold the screen rubber-bands back; crossing the commit
//      point fires Haptics.selection() so you feel it without looking.
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
            let breath = hasFinished ? 1.0 : breathScale(elapsed: elapsed, accelerated: accelerated)
            let progress = min(1, max(0, 1 - remainingExact / totalDuration))

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    kicker
                        .padding(.top, Space.xs)

                    Spacer()

                    timeHero(remaining: remainingExact, breath: breath)
                    ofTotalLine
                        .padding(.top, Space.sm)
                    progressBar(progress: progress)
                        .padding(.top, Space.lg)

                    Spacer()

                    nextLine
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                swipeAffordances
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

    // MARK: - Pieces

    private var kicker: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Tint.inProgress)
                .frame(width: 7, height: 7)
            Text(hasFinished ? "Go" : "Rest")
                .font(Typography.sectionLabel)
                .foregroundStyle(Tint.inProgress)
        }
    }

    private func timeHero(remaining: TimeInterval, breath: Double) -> some View {
        DigitTicker(
            value: remaining,
            font: .system(size: 96, weight: .bold, design: .monospaced),
            color: Ink.primary,
            formatter: { time in
                let total = Int(time.rounded(.up))
                return String(format: "%d:%02d", total / 60, total % 60)
            }
        )
        .scaleEffect(breath, anchor: .leading)
        .animation(.easeInOut(duration: 0.2), value: breath)
    }

    private var ofTotalLine: some View {
        Text("of \(formatted(totalDuration))")
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(Ink.tertiary)
            .opacity(hasFinished ? 0 : 1)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 3)
                Capsule()
                    .fill(Tint.inProgress)
                    .frame(width: max(0, g.size.width * (1 - progress)), height: 3)
            }
        }
        .frame(height: 3)
    }

    @ViewBuilder
    private var nextLine: some View {
        if let nextSetLabel {
            HStack(spacing: 10) {
                Text("Next")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Tint.inProgress)
                Rectangle()
                    .fill(Surface.edge)
                    .frame(width: 1, height: 12)
                Text(nextSetLabel)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// Two always-visible swipe affordances at the top and bottom
    /// edges, brightening (and flipping to Volt) as the user crosses
    /// each commit threshold. Words, not buttons — the chevron just
    /// teaches the swipe direction.
    private var swipeAffordances: some View {
        VStack {
            affordanceChip(
                symbol: "chevron.compact.down",
                label: "Skip",
                visibility: hintVisibility(dragOffset, direction: .down)
            )
            .padding(.top, 120)
            Spacer()
            affordanceChip(
                symbol: "chevron.compact.up",
                label: "+30s",
                visibility: hintVisibility(dragOffset, direction: .up)
            )
            .padding(.bottom, 130)
        }
        .allowsHitTesting(false)
    }

    private func affordanceChip(symbol: String, label: String, visibility: Double) -> some View {
        let restingOpacity = 0.22
        let activeOpacity = 0.95
        let opacity = restingOpacity + (activeOpacity - restingOpacity) * visibility
        let committed = visibility >= 1
        return VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.5)
        }
        .foregroundStyle(committed ? Tint.inProgress : Color.white.opacity(opacity))
        .scaleEffect(0.96 + 0.06 * visibility)
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
            // First swipe on a still-counting timer: snap to 0 / Go
            // state, but stay on the overlay. The user commits with a
            // second swipe to actually return to the exercise card —
            // a confirmation beat in the "I'm ready" state.
            endTime = Date()
            hasFinished = true
        } else {
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

    /// Gentle breath to set a calming pace.
    /// 12 BPM normal (5s period), ~30 BPM accelerated (2s period).
    /// Amplitudes are deliberately tiny on a numeral (vs the old orb)
    /// so the hero pulses, never bounces. (1 - cos) phase starts at 1.0.
    private func breathScale(elapsed: Double, accelerated: Bool) -> Double {
        let period = accelerated ? 2.0 : 5.0
        let amplitude = accelerated ? 0.03 : 0.02
        let phase = (1 - cos(2 * .pi * elapsed / period)) / 2
        return 1.0 + amplitude * phase
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

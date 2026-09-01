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
import UIKit
import VivoKit

struct BreathingTimer: View {
    let duration: TimeInterval
    var nextSetLabel: String? = nil
    var onComplete: () -> Void = {}
    var onSkip: () -> Void = {}
    var onExtend: (TimeInterval) -> Void = { _ in }
    var onZero: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    /// Drives the idle drift on the swipe affordances — the Skip chevron
    /// floats down, the +30s chevron floats up, on a slow repeat loop so
    /// the gestures advertise themselves without shouting.
    @State private var affordanceNudge = false

    private let threshold: CGFloat = 90
    private let maxDrag: CGFloat = 140

    init(
        duration: TimeInterval,
        nextSetLabel: String? = nil,
        onComplete: @escaping () -> Void = {},
        onSkip: @escaping () -> Void = {},
        onExtend: @escaping (TimeInterval) -> Void = { _ in },
        onZero: @escaping () -> Void = {}
    ) {
        self.duration = duration
        self.nextSetLabel = nextSetLabel
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.onExtend = onExtend
        self.onZero = onZero
        let now = Date()
        let end = now.addingTimeInterval(duration)
        self._startTime = State(initialValue: now)
        self._endTime = State(initialValue: end)
        self._totalDuration = State(initialValue: duration)
        self._secondsRemaining = State(initialValue: Int(duration.rounded(.up)))
    }

    var body: some View {
        Group {
            if reduceMotion {
                let remainingExact = max(0, endTime.timeIntervalSince(Date()))
                let progress = min(1, max(0, 1 - remainingExact / totalDuration))
                content(breath: 1.0, progress: progress, remaining: remainingExact)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let now = context.date
                    let remainingExact = max(0, endTime.timeIntervalSince(now))
                    let elapsed = max(0, now.timeIntervalSince(startTime))
                    let accelerated = remainingExact > 0 && remainingExact <= 10
                    let breath = hasFinished ? 1.0 : breathScale(elapsed: elapsed, accelerated: accelerated)
                    let progress = min(1, max(0, 1 - remainingExact / totalDuration))
                    content(breath: breath, progress: progress, remaining: remainingExact)
                }
            }
        }
        .onAppear {
            Haptics.prepare()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                affordanceNudge = true
            }
        }
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

    // MARK: - Content

    private func content(breath: Double, progress: Double, remaining: TimeInterval) -> some View {
        ZStack {
            Surface.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                kicker
                    .padding(.top, Space.xs)

                Spacer()

                timeHero(remaining: remaining, breath: breath)
                ofTotalLine
                    .padding(.top, Space.sm)
                progressBar(progress: progress)
                    .padding(.top, Space.lg)
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityGestureHints
                        .padding(.top, Space.md)
                }

                Spacer()

                nextLine
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if !dynamicTypeSize.isAccessibilitySize {
                swipeAffordances
            }
        }
        .offset(y: dragOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Surface.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .gesture(skipOrExtendGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest timer")
        .accessibilityIdentifier("restTimerOverlay")
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityAction(named: hasFinished ? "Return to workout" : "Skip rest") { skipNow() }
        .accessibilityAction(named: "Add 30 seconds") { extend(by: 30) }
        .focusable()
        .accessibilityRespondsToUserInteraction(true)
    }

    // MARK: - Pieces

    private var kicker: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(Tint.inProgress)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(hasFinished ? "Go" : "Rest")
                .panelLegendType()
                .foregroundStyle(Tint.inProgress)
        }
    }

    /// The hero readout, LCD-style: the live time rendered over its
    /// own unlit ghost segments. In the final 10 seconds the digits
    /// switch to Volt with a glow — the machine raising its voice —
    /// without a single glyph moving (panel discipline).
    private func timeHero(remaining: TimeInterval, breath: Double) -> some View {
        let urgent = !hasFinished && remaining > 0 && remaining <= 10
        return ZStack(alignment: .leading) {
            Text(SegmentDisplay.ghost(for: Self.timeString(remaining)))
                .font(Typography.bigMetric)
                .foregroundStyle(Ink.primary.opacity(0.06))
                .monospacedDigit()
                .accessibilityHidden(true)
            DigitTicker(
                value: remaining,
                font: Typography.bigMetric,
                color: urgent ? Tint.inProgress : Ink.primary,
                formatter: { Self.timeString($0) }
            )
            .shadow(color: urgent ? Tint.inProgress.opacity(0.35) : .clear, radius: 14)
        }
        .scaleEffect(reduceMotion ? 1.0 : breath, anchor: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: breath)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: urgent)
    }

    private static func timeString(_ time: TimeInterval) -> String {
        let total = Int(time.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var ofTotalLine: some View {
        Text("of \(formatted(totalDuration))")
            .font(Typography.metricUnit)
            .foregroundStyle(Ink.tertiary)
            .opacity(hasFinished ? 0 : 1)
    }

    /// The rest gauge: a discrete segment ladder that depletes
    /// click-by-click as the charge drains, not a smear.
    private func progressBar(progress: Double) -> some View {
        SegmentLadder(fraction: 1 - progress, segments: 40, tint: Tint.inProgress)
    }

    /// At accessibility text sizes the edge-positioned gesture prompts would
    /// collide with the expanded next-set block. Keep the same instructions
    /// in the normal content flow; VoiceOver receives named actions instead.
    private var accessibilityGestureHints: some View {
        HStack {
            Label(hasFinished ? "Go" : "Skip", systemImage: "chevron.down")
            Spacer()
            Label("+30s", systemImage: "chevron.up")
        }
        .font(Typography.metricMicro)
        .foregroundStyle(Ink.tertiary)
        .dynamicTypeSize(.large)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var nextLine: some View {
        if let nextSetLabel {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Next")
                        .panelLegendType()
                        .foregroundStyle(Tint.inProgress)
                    Text(nextSetLabel)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: Space.md) {
                    Text("Next")
                        .panelLegendType()
                        .foregroundStyle(Tint.inProgress)
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(width: 1, height: 12)
                        .accessibilityHidden(true)
                    Text(nextSetLabel)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    /// Two always-visible swipe affordances at the top and bottom
    /// edges, brightening (and flipping to Volt) as the user crosses
    /// each commit threshold. Words, not buttons — the chevron sits on
    /// the gesture side of the word (below Skip/Go, above +30s) and
    /// drifts gently that way at idle on a slow loop. The pull-down word
    /// follows the two-beat skip: "Skip" cuts the timer to zero, then
    /// "Go" (mirroring the kicker) dismisses back to the exercise card.
    private var swipeAffordances: some View {
        VStack {
            affordanceChip(
                symbol: "chevron.compact.down",
                label: hasFinished ? "Go" : "Skip",
                visibility: hintVisibility(dragOffset, direction: .down),
                drift: 5,
                iconFirst: false
            )
            .padding(.top, 120)
            Spacer()
            affordanceChip(
                symbol: "chevron.compact.up",
                label: "+30s",
                visibility: hintVisibility(dragOffset, direction: .up),
                drift: -5,
                iconFirst: true
            )
            .padding(.bottom, 130)
        }
        .allowsHitTesting(false)
        // These words only teach the physical swipe and are hidden from
        // assistive technologies, which receive named actions instead. Keep
        // them compact so accessibility text sizes leave room for the actual
        // next-set description.
        .dynamicTypeSize(.large)
        .accessibilityHidden(true)
    }

    private func affordanceChip(symbol: String, label: String, visibility: Double, drift: CGFloat, iconFirst: Bool) -> some View {
        let restingOpacity = 0.45
        let activeOpacity = 0.95
        let opacity = restingOpacity + (activeOpacity - restingOpacity) * visibility
        let committed = visibility >= 1
        return VStack(spacing: 4) {
            if iconFirst {
                affordanceChevron(symbol: symbol, drift: drift)
                affordanceLabel(label)
            } else {
                affordanceLabel(label)
                affordanceChevron(symbol: symbol, drift: drift)
            }
        }
        .foregroundStyle(committed ? Tint.inProgress : Ink.primary.opacity(opacity))
        .scaleEffect(reduceMotion ? 1.0 : 0.96 + 0.06 * visibility)
    }

    private func affordanceChevron(symbol: String, drift: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(.title, weight: .semibold))
            .offset(y: reduceMotion ? 0 : (affordanceNudge ? drift : 0))
    }

    private func affordanceLabel(_ label: String) -> some View {
        Text(label)
            .font(Typography.metricUnit)
            .tracking(0.5)
    }

    // MARK: - Gesture

    private var skipOrExtendGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                let raw = v.translation.height
                dragOffset = clampWithRubber(raw)

                let down = raw > threshold
                let up = raw < -threshold
                if down, !pastSkipThreshold {
                    pastSkipThreshold = true
                    Haptics.selection(playsSound: false)
                }
                if !down { pastSkipThreshold = false }
                if up, !pastExtendThreshold {
                    pastExtendThreshold = true
                    Haptics.selection(playsSound: false)
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
                if reduceMotion {
                    dragOffset = 0
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                        dragOffset = 0
                    }
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
        if remaining == 10, !hasFiredWarning {
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
                Haptics.success(sound: .timerExpired)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Rest complete. Go."
                )
                onComplete()
            }
        default: break
        }
    }

    private var accessibilityValue: String {
        let remaining = "\(secondsRemaining) seconds remaining of \(formatted(totalDuration))"
        guard let nextSetLabel else { return remaining }
        return "\(remaining). Next: \(nextSetLabel)"
    }

    private func skipNow() {
        if !hasFinished {
            // First swipe on a still-counting timer: snap to 0 / Go
            // state, but stay on the overlay. The user commits with a
            // second swipe to actually return to the exercise card —
            // a confirmation beat in the "I'm ready" state. onZero
            // lets the owner move the shared rest deadline too, so
            // external surfaces (Live Activity, MiniBar) don't keep
            // counting the old rest.
            endTime = Date()
            hasFinished = true
            onZero()
        } else {
            onSkip()
        }
    }

    private func extend(by seconds: TimeInterval) {
        // Clamp to now so extending from the Go state grants the full
        // 30s instead of counting from the moment the timer hit zero —
        // mirrors WorkoutSession.didExtendRest.
        endTime = max(endTime, Date()).addingTimeInterval(seconds)
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

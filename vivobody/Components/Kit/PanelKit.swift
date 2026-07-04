//
//  PanelKit.swift
//  vivobody
//
//  The physical-device vocabulary: the pieces that make the app's
//  pixels obey machine physics the way its haptics and sounds already
//  do. No skeuomorphism — no leather, no brushed metal. Devices are
//  evoked through behavior (light that overdrives and decays, discrete
//  segments, silkscreened legends), never through texture.
//
//  Pieces:
//    • panelLegendType / panelLegend — silkscreen label treatment:
//      tiny, monospaced, uppercase, wide-tracked, like the printed
//      legends on an instrument faceplate.
//    • LEDLamp — an indicator lamp with true LED behavior: off is a
//      dim ring, armed glows and breathes at standby, lit overdrives
//      past resting brightness then settles with an afterglow.
//    • SegmentLadder — a discrete segment bar. Devices count in
//      steps; a ladder fills click-by-click instead of smearing.
//    • SegmentReadout + SegmentDisplay.ghost — LCD-style numeric
//      readout with unlit "ghost segments" behind the value, the
//      machine-voice treatment for transient utterances.
//

import SwiftUI

// MARK: - Silkscreen legend

extension View {
    /// Type-only silkscreen treatment: caption-mono, semibold,
    /// uppercase, wide tracking. Caller owns the color (legends are
    /// usually `Ink.tertiary`, but accented panels keep their tint).
    func panelLegendType() -> some View {
        self
            .font(.system(.caption2, design: .monospaced, weight: .semibold))
            .tracking(1.6)
            .textCase(.uppercase)
    }

    /// The standard printed legend: silkscreen type in tertiary ink.
    func panelLegend() -> some View {
        panelLegendType().foregroundStyle(Ink.tertiary)
    }
}

// MARK: - LED lamp

enum LEDLampState: Equatable {
    /// Unlit — a dim hairline ring.
    case off
    /// Standby — ring lit in the live accent, breathing at sub-1Hz
    /// like a device that's on and waiting.
    case armed
    /// Lit — filled with the completion accent. Entering this state
    /// overdrives past resting brightness, then decays to a faint
    /// persistent glow (phosphor afterglow), never a plain cross-fade.
    case lit
}

/// An indicator lamp that behaves like an LED rather than a tinted
/// circle. Constant outer frame across all states, so a row of lamps
/// never reflows as they light — panel discipline.
struct LEDLamp: View {
    let state: LEDLampState
    var size: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var overdrive: Bool = false
    @State private var breathDim: Bool = false
    @State private var overdriveTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            switch state {
            case .off:
                Circle()
                    .strokeBorder(Ink.quaternary, lineWidth: 2)
                    .frame(width: size - 2, height: size - 2)
            case .armed:
                Circle()
                    .stroke(Tint.inProgress, lineWidth: 3)
                    .frame(width: size + 2, height: size + 2)
                    .opacity(breathDim ? 0.68 : 1.0)
                    .shadow(color: Tint.inProgress.opacity(breathDim ? 0.10 : 0.30), radius: 4)
            case .lit:
                Circle()
                    .fill(Tint.complete)
                    .frame(width: size, height: size)
                    .brightness(overdrive ? 0.32 : 0)
                    .scaleEffect(overdrive ? 1.22 : 1.0)
                    .shadow(
                        color: Tint.complete.opacity(overdrive ? 0.85 : 0.30),
                        radius: overdrive ? 9 : 3
                    )
            }
        }
        .frame(width: size + 6, height: size + 6)
        .onChange(of: state) { old, new in
            if new == .lit, old != .lit { fireOverdrive() }
            if new == .armed {
                startBreathing()
            } else if old == .armed {
                stopBreathing()
            }
        }
        .onAppear { if state == .armed { startBreathing() } }
        .onDisappear { overdriveTask?.cancel() }
    }

    private func fireOverdrive() {
        guard !reduceMotion else { return }
        overdriveTask?.cancel()
        overdriveTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.09)) { overdrive = true }
            try? await Task.sleep(for: .milliseconds(130))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.7)) { overdrive = false }
        }
    }

    private func startBreathing() {
        guard !reduceMotion else { return }
        breathDim = false
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathDim = true
        }
    }

    private func stopBreathing() {
        withAnimation(.easeOut(duration: 0.2)) { breathDim = false }
    }
}

// MARK: - Segment ladder

/// A discrete proportion bar: N segments, filled from the leading
/// edge. The mechanical-honesty counterpart to a continuous capsule
/// fill — state changes in visible clicks, matching the app's
/// detent-based sound world. Any non-zero fraction lights at least
/// one segment so "a little" never reads as "nothing."
struct SegmentLadder: View {
    /// 0…1 portion of the ladder to light.
    let fraction: Double
    var segments: Int = 24
    var tint: Color = Ink.secondary
    var height: CGFloat = 3
    var spacing: CGFloat = 2

    var body: some View {
        let count = max(1, segments)
        let clamped = min(1, max(0, fraction))
        let lit = clamped <= 0 ? 0 : max(1, Int((clamped * Double(count)).rounded()))
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < lit ? tint : Surface.edge)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Segment readout

enum SegmentDisplay {
    /// The unlit-segment ghost for a numeric string: every digit
    /// becomes an "8" (all segments energized), punctuation and
    /// letters pass through so the ghost's advance matches the value
    /// glyph-for-glyph under a monospaced font.
    static func ghost(for text: String) -> String {
        String(text.map { $0.isNumber ? "8" : $0 })
    }
}

/// LCD-style numeric readout: the value rendered over its own unlit
/// ghost segments, with a faint glow on the lit glyphs. References
/// display technology, not material — the honest-digital voice for
/// machine utterances (countdowns, deltas, records). Use sparingly;
/// it only stays special if it never appears in chrome.
struct SegmentReadout: View {
    let text: String
    var font: Font = Typography.metricLg
    var tint: Color = Tint.primary
    var glow: Bool = true

    var body: some View {
        ZStack(alignment: .leading) {
            Text(SegmentDisplay.ghost(for: text))
                .font(font)
                .foregroundStyle(tint.opacity(0.08))
                .monospacedDigit()
            Text(text)
                .font(font)
                .foregroundStyle(tint)
                .monospacedDigit()
                .shadow(color: glow ? tint.opacity(0.45) : .clear, radius: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

#Preview("Panel kit") {
    struct Demo: View {
        @State private var lamp: LEDLampState = .armed
        @State private var fraction: Double = 0.6

        var body: some View {
            VStack(alignment: .leading, spacing: Space.section) {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Set 2 of 4").panelLegend()
                    HStack(spacing: Space.md) {
                        LEDLamp(state: .lit)
                        LEDLamp(state: lamp)
                        LEDLamp(state: .off)
                    }
                    Button("Toggle lamp") { lamp = lamp == .lit ? .armed : .lit }
                        .foregroundStyle(Ink.secondary)
                }
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Ladder").panelLegend()
                    SegmentLadder(fraction: fraction, tint: Tint.primary)
                    Slider(value: $fraction)
                }
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Readout").panelLegend()
                    SegmentReadout(text: "1:47", font: Typography.metricHero)
                }
            }
            .padding(Space.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black.ignoresSafeArea())
        }
    }
    return Demo().preferredColorScheme(.dark)
}

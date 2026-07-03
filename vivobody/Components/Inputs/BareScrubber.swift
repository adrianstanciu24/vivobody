//
//  BareScrubber.swift
//  vivobody
//
//  Vertical drag to adjust a numeric value — the same gesture, feel,
//  and haptics as NumberScrubber, but stripped of all chrome. No
//  chip, no liquid fill, no glass: just the number itself, rendered
//  as a huge monospaced odometer on black.
//
//  This is the instrument-design counterpart to NumberScrubber. The
//  product principles call for "huge, monospaced, weight-bearing
//  numerals" with the value being something you can physically move —
//  so the digit IS the control, not a value sitting inside a control.
//
//  Behaviour (identical to NumberScrubber, intentionally):
//    • up = increase, down = decrease.
//    • Haptics.tick() the frame the value snaps to a new step.
//    • Haptics.rigid() once when hitting the min or max wall.
//    • Past the wall, the number rubber-bands with asymptotic decay.
//    • Release springs the rubber-band back to zero.
//

import SwiftUI

struct BareScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var pointsPerStep: CGFloat = 10
    var fontSize: CGFloat = 104
    var unit: String = ""
    var unitFontSize: CGFloat = 14
    var numberColor: Color = Ink.primary
    var unitColor: Color = Ink.tertiary
    var formatter: ((Double) -> String)? = nil
    /// VoiceOver label for the control. Callers should pass a
    /// contextual noun ("Weight", "Reps", "Hold duration") so
    /// VoiceOver announces what is being adjusted, not just the value.
    var accessibilityLabel: String? = nil
    /// When true, this scrubber displays the first-use drag affordance
    /// (faint up/down chevrons) until the user has scrubbed any number
    /// once. Use for the in-workout hero numbers where the gesture is
    /// least obvious; leave false on gallery / editor surfaces.
    var showsScrubHint: Bool = false
    /// When true, this scrubber also performs the one-time nudge
    /// animation (the number bobs up a notch and settles back with a
    /// tick) the moment it becomes the active hint surface. Reserve
    /// for the single primary number per card so two scrubbbers never
    /// nudge at once.
    var performsScrubNudge: Bool = false
    /// When true, the number + unit shrink to fit the available width
    /// instead of clipping. Needed for the large hero numbers: a kg
    /// weight renders with a decimal ("112.5") and at 104pt the row
    /// can overrun the card and truncate the unit. Off elsewhere so
    /// intrinsic-width layouts (editors, galleries) are unaffected.
    var fitsWidth: Bool = false
    /// Voice of the per-step tick. Pass `.deep` on load scrubbers so
    /// weight sounds heavier than reps/sets/duration.
    var tickTone: Haptics.TickTone = .standard

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Retired permanently (app-wide) the first time the user
    /// completes a real scrub on any BareScrubber. See
    /// `SettingsKey.hasScrubbedNumber`.
    @AppStorage(SettingsKey.hasScrubbedNumber) private var hasScrubbed: Bool = SettingsDefaults.hasScrubbedNumber

    @State private var dragStartValue: Double = 0
    @State private var rubberOffset: CGFloat = 0
    @State private var lastStepReported: Int = 0
    @State private var didHitMin: Bool = false
    @State private var didHitMax: Bool = false
    @State private var isDragging: Bool = false

    /// Nudge-bob offset for the first-use hint. Added to `rubberOffset`
    /// so the bob rides the same offset channel as the drag rubber-band
    /// without interfering with it. Zeroed the instant a real drag
    /// begins (see `scrubGesture`).
    @State private var nudgeOffset: CGFloat = 0
    /// Per-mount guard so the nudge fires at most once per appearance.
    @State private var hasNudged: Bool = false
    /// Cancellable owner of the nudge sequence so a drag can abort it.
    @State private var nudgeTask: Task<Void, Never>? = nil

    /// Intrinsic width of the number + unit row, measured fixed-size so
    /// it ignores the parent's proposal. Compared against
    /// `availableWidth` to derive `fitScale`. Only used when
    /// `fitsWidth` is true.
    @State private var naturalWidth: CGFloat = 0
    /// Width the scrubber is actually offered by its container.
    @State private var availableWidth: CGFloat = 0

    /// Value-settle spring. When Reduce Motion is on, skip the
    /// decorative spring so the number snaps to its new value.
    private var valueAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75)
    }

    /// Drag-state transition (scale). When Reduce Motion is on,
    /// snap between states instead of springing.
    private var dragStateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)
    }

    var body: some View {
        heroLayout
        .offset(y: rubberOffset + nudgeOffset)
        .scaleEffect(reduceMotion ? 1.0 : (isDragging ? 1.04 : 1.0))
        .animation(valueAnimation, value: value)
        .animation(dragStateAnimation, value: isDragging)
        .animation(.easeInOut(duration: 0.3), value: showsScrubHint)
        .animation(.easeInOut(duration: 0.4), value: hasScrubbed)
        .contentShape(Rectangle())
        .gesture(scrubGesture)
        .onAppear { if showsScrubHint, performsScrubNudge { startNudge() } }
        .onChange(of: showsScrubHint) { _, active in
            if active {
                if performsScrubNudge { startNudge() }
            } else {
                // Leaving the active surface: abort any in-flight
                // nudge so its tick never lands on an off-screen card.
                nudgeTask?.cancel()
                nudgeOffset = 0
            }
        }
        .onDisappear { nudgeTask?.cancel() }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityValue("\(formattedValue)\(unit.isEmpty ? "" : " \(unit)")")
        .accessibilityHint("Swipe up or down to change")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: stepValue(by: 1)
            case .decrement: stepValue(by: -1)
            @unknown default: break
            }
        }
        .focusable()
        .accessibilityRespondsToUserInteraction(true)
    }

    // MARK: - Hero layout

    /// The number + its unit. Rendered with the rolling DigitTicker,
    /// which is an HStack of per-glyph Texts — so it can't be reined in
    /// with `minimumScaleFactor`; width is handled by `fitsWidth`.
    private var numberUnitRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
            DigitTicker(
                value: value,
                font: .system(size: fontSize, weight: .bold, design: .monospaced),
                color: numberColor,
                fractionalDigits: step.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1,
                formatter: formatter
            )

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: unitFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(unitColor)
            }
        }
    }

    @ViewBuilder
    private var hintChevrons: some View {
        if showsScrubHint && !hasScrubbed {
            ScrubHintChevrons()
                .transition(.opacity)
        }
    }

    /// When `fitsWidth` is off, the number keeps its intrinsic width
    /// (galleries, editors). When on, the number row is measured
    /// fixed-size and uniformly scaled down so it — and its unit —
    /// always fit the offered width, never clipping. `scaleEffect`
    /// doesn't change layout, so measuring stays free of feedback.
    @ViewBuilder
    private var heroLayout: some View {
        if fitsWidth {
            HStack(alignment: .center, spacing: Space.sm) {
                numberUnitRow
                    .fixedSize(horizontal: true, vertical: false)
                    .background(widthReader($naturalWidth))
                    .scaleEffect(fitScale, anchor: .leading)
                    .frame(width: fitScale < 1 ? naturalWidth * fitScale : nil, alignment: .leading)
                hintChevrons
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(widthReader($availableWidth))
        } else {
            HStack(alignment: .center, spacing: Space.sm) {
                numberUnitRow
                hintChevrons
            }
        }
    }

    /// Uniform shrink factor (≤ 1) that fits the number row into the
    /// offered width, reserving a little room for the chevrons while
    /// the first-use hint is showing. 1 when it already fits.
    private var fitScale: CGFloat {
        guard fitsWidth, naturalWidth > 0, availableWidth > 0 else { return 1 }
        let reserve: CGFloat = (showsScrubHint && !hasScrubbed) ? (Space.sm + 16) : 0
        let target = max(1, availableWidth - reserve)
        guard naturalWidth > target else { return 1 }
        return target / naturalWidth
    }

    /// Writes a view's measured width into `binding`. Uses
    /// onAppear/onChange (main-actor) rather than a PreferenceKey so it
    /// stays clear of Swift 6 Sendable-closure warnings.
    private func widthReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { binding.wrappedValue = proxy.size.width }
                .onChange(of: proxy.size.width) { _, w in binding.wrappedValue = w }
        }
    }

    // MARK: - First-use hint

    // The animated chevron pair lives in its own `ScrubHintChevrons`
    // type below so it can own the repeating-bob animation state
    // without bloating the scrubber's own @State surface.

    /// One-time first-use nudge: the number bobs up one notch and
    /// settles back, with a tick at the apex — motion + haptic
    /// demonstrating "this digit moves vertically" without a word of
    /// onboarding. Runs only while the gesture is still unlearned and
    /// not under Reduce Motion (which skips decorative motion; the
    /// chevrons alone carry the cue there). Aborts the instant a real
    /// drag begins so the bob never fights the user's finger.
    private func startNudge() {
        guard !hasScrubbed, !hasNudged, isEnabled, !reduceMotion else { return }
        hasNudged = true
        nudgeTask?.cancel()
        nudgeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, !isDragging else { return }
            withAnimation(.easeOut(duration: 0.28)) { nudgeOffset = -12 }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, !isDragging else { nudgeOffset = 0; return }
            Haptics.tick(tone: tickTone)
            try? await Task.sleep(for: .milliseconds(170))
            guard !Task.isCancelled, !isDragging else { nudgeOffset = 0; return }
            withAnimation(.easeInOut(duration: 0.34)) { nudgeOffset = 0 }
        }
    }

    // MARK: - Gesture

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard isEnabled else { return }
                if !isDragging {
                    isDragging = true
                    // Abort any in-flight first-use nudge so its bob
                    // never competes with the user's real drag.
                    nudgeTask?.cancel()
                    nudgeOffset = 0
                    dragStartValue = value
                    lastStepReported = 0
                    didHitMin = false
                    didHitMax = false
                }

                let translationY = drag.translation.height
                let stepDelta = Int((-translationY / pointsPerStep).rounded())
                let proposedValue = dragStartValue + Double(stepDelta) * step
                let clamped = min(max(proposedValue, range.lowerBound), range.upperBound)

                if value != clamped {
                    value = clamped
                }

                let absDrag = abs(translationY)
                let inRangeDragPoints = abs(clamped - dragStartValue) / step * pointsPerStep
                let pointsOver = max(0, absDrag - inRangeDragPoints)

                if proposedValue < range.lowerBound {
                    rubberOffset = rubberband(pointsOver)
                    if !didHitMin {
                        Haptics.rigid()
                        didHitMin = true
                    }
                } else if proposedValue > range.upperBound {
                    rubberOffset = -rubberband(pointsOver)
                    if !didHitMax {
                        Haptics.rigid()
                        didHitMax = true
                    }
                } else {
                    rubberOffset = 0
                    didHitMin = false
                    didHitMax = false
                }

                let actualStepDelta = Int(((clamped - dragStartValue) / step).rounded())
                if actualStepDelta != lastStepReported {
                    // Pitch tracks the drag: each step from the grab
                    // point shifts the tick ~30 cents, so scrubbing up
                    // literally sounds like the number going up.
                    Haptics.tick(pitch: Double(actualStepDelta) / 20, tone: tickTone)
                    lastStepReported = actualStepDelta
                }
            }
            .onEnded { _ in
                isDragging = false
                if reduceMotion {
                    rubberOffset = 0
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                        rubberOffset = 0
                    }
                }
                // The first scrub that actually moved the value
                // retires the first-use affordance app-wide. Animate
                // the flag so the chevrons fade, not snap, away.
                if !hasScrubbed, value != dragStartValue {
                    withAnimation(.easeOut(duration: 0.4)) { hasScrubbed = true }
                }
            }
    }

    // MARK: - Helpers

    /// iOS-style asymptotic decay: approaches `max` as input grows.
    private func rubberband(_ x: CGFloat, maxStretch: CGFloat = 50) -> CGFloat {
        maxStretch * (1 - 1 / (x / maxStretch + 1))
    }

    private func stepValue(by direction: Int) {
        guard isEnabled else { return }
        let next = value + Double(direction) * step
        let clamped = min(max(next, range.lowerBound), range.upperBound)
        if clamped != value {
            value = clamped
            Haptics.tick(pitch: Double(direction) * 0.15, tone: tickTone)
            // A VoiceOver adjustable action is also a "real scrub" —
            // retire the hint so it never nags an accessible user who
            // has already demonstrated the gesture.
            if !hasScrubbed {
                withAnimation(.easeOut(duration: 0.4)) { hasScrubbed = true }
            }
        } else {
            Haptics.rigid()
        }
    }

    private var formattedValue: String {
        if let formatter { return formatter(value) }
        let isIntegerStep = step.truncatingRemainder(dividingBy: 1) == 0
        return isIntegerStep ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// Animated up/down chevrons that bob in their respective directions
/// to telegraph the vertical scrub gesture. A travelling highlight
/// cycles up → down: the up chevron lifts and brightens, settles, then
/// the down chevron drops and brightens. Calm and repeating — not a
/// frantic pulse. Reduce Motion freezes the pair to a static, evenly
/// lit state (motion is decorative; the cue still reads). Lives only
/// while the first-use hint is shown and is removed entirely once the
/// user has scrubbed once, so the loop never runs for a returning user.
private struct ScrubHintChevrons: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the alternating bob. false = up chevron active, true =
    /// down chevron active.
    @State private var phase: Bool = false

    private static let travel: CGFloat = 5
    private static let cycle: Animation = .easeInOut(duration: 1.1)

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.up")
                .offset(y: reduceMotion ? 0 : (phase ? 0 : -Self.travel))
                .opacity(reduceMotion ? 1.0 : (phase ? Opacity.faint : 1.0))

            Image(systemName: "chevron.down")
                .offset(y: reduceMotion ? 0 : (phase ? Self.travel : 0))
                .opacity(reduceMotion ? 1.0 : (phase ? 1.0 : Opacity.faint))
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Ink.tertiary)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Self.cycle.repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

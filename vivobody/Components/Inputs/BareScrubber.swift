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
//    • Haptics.rigid() once when hitting the min or max wall —
//      raised in pitch at the max so top and bottom read differently.
//    • Past the wall, the number rubber-bands with asymptotic decay.
//    • Release springs the rubber-band back to zero.
//

import VivoKit
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
    /// When true, the number + unit are uniformly scaled so the
    /// widest value the range can produce fits the offered width.
    /// Sizing against the worst case (not the live value) keeps the
    /// scale constant for the whole scrub — the hero never resizes
    /// when the digit count changes (99.5 → 100.0). Off elsewhere so
    /// intrinsic-width layouts (editors, galleries) are unaffected.
    var fitsWidth: Bool = false
    /// Voice of the per-step tick. Pass `.deep` on load scrubbers so
    /// weight sounds heavier than reps/sets/duration.
    var tickTone: Haptics.TickTone = .standard
    /// Extra hit-test reach (points) beyond the glyphs on every side.
    /// The hero numbers are huge but their touch frame hugs the ink —
    /// a fast, sloppy grab often lands just above or beside the digits
    /// and dies on dead card space. Slop keeps those grabs alive
    /// without moving any pixels. Leave 0 on dense editor layouts.
    var hitSlop: CGFloat = 0
    /// When true, a graduation rail (tick marks sliding under a fixed
    /// needle) fades in beside the number while a scrub is live — the
    /// encoder's mechanism made visible, gone the moment you let go.
    /// Reserve for the full-width hero scrubbers; dense editor rows
    /// have no room for it.
    var showsRail: Bool = false

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

    /// Flywheel coast. A released flick keeps the value rolling
    /// through detents with decaying velocity — the number has mass.
    /// True while the coast task is stepping; suppresses the settle
    /// spring so each coast detent lands as a crisp mechanical click.
    @State private var isCoasting: Bool = false
    /// Cancellable owner of the coast run. A new touch anywhere on
    /// the scrubber grabs the flywheel and stops it instantly.
    @State private var coastTask: Task<Void, Never>? = nil

    /// Wall flash — the visual twin of the rigid end-stop haptic.
    /// One event, three senses: hitting a range wall flashes a thin
    /// accent line on the wall's side of the number (top = max,
    /// bottom = min) that decays like a struck lamp.
    @State private var wallFlashEdge: Edge? = nil
    @State private var wallFlashOpacity: Double = 0

    /// Axis ownership for the in-flight drag. The scrubber only acts
    /// on vertically-dominant drags — the mirror of SwipePager's
    /// horizontal claim — so a page swipe that begins on a hero
    /// number and drifts a few points vertically no longer edits the
    /// value as a side effect.
    private enum AxisClaim { case undecided, vertical, horizontal }
    @State private var axisClaim: AxisClaim = .undecided
    /// Vertical translation already spent at the moment the claim
    /// resolved. Subtracted from later events so the value starts
    /// moving from the claim point, not the touch-down point — which
    /// also gives every drag a small dead-band that keeps sloppy taps
    /// from nudging the value by a step.
    @State private var claimBaselineY: CGFloat = 0
    /// True only while the system considers the drag alive. Resets
    /// automatically on end AND on cancellation (sheet steal, incoming
    /// call), which `onEnded` does not cover — used to sweep up stale
    /// drag state so the next scrub never starts from a ghost anchor.
    @GestureState private var gestureActive: Bool = false

    /// Movement (points) needed before a drag claims an axis.
    private static let axisClaimDistance: CGFloat = 8

    /// Nudge-bob offset for the first-use hint. Added to `rubberOffset`
    /// so the bob rides the same offset channel as the drag rubber-band
    /// without interfering with it. Zeroed the instant a real drag
    /// begins (see `scrubGesture`).
    @State private var nudgeOffset: CGFloat = 0
    /// Per-mount guard so the nudge fires at most once per appearance.
    @State private var hasNudged: Bool = false
    /// Cancellable owner of the nudge sequence so a drag can abort it.
    @State private var nudgeTask: Task<Void, Never>? = nil

    /// Intrinsic width of the number + unit row for the CURRENT value,
    /// measured fixed-size so it ignores the parent's proposal. Used
    /// only to reserve the row's scaled layout width; the scale itself
    /// comes from `templateWidth`. Only used when `fitsWidth` is true.
    @State private var naturalWidth: CGFloat = 0
    /// Intrinsic width of the hidden worst-case sizing row (the
    /// range's upper bound, formatted). `fitScale` derives from this,
    /// not from the live value, so the scale stays constant across
    /// digit-count changes. Only used when `fitsWidth` is true.
    @State private var templateWidth: CGFloat = 0
    /// Width the scrubber is actually offered by its container.
    @State private var availableWidth: CGFloat = 0

    /// Value-settle spring. When Reduce Motion is on, skip the
    /// decorative spring so the number snaps to its new value.
    /// Suppressed entirely mid-drag: a live scrub must track the
    /// finger 1:1 — the half-second spring made fast scrubs lag and
    /// keep rolling after the finger stopped. Suppressed mid-coast
    /// too: flywheel detents click, they don't smear.
    private var valueAnimation: Animation? {
        guard !isDragging, !isCoasting else { return nil }
        return reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75)
    }

    /// Drag-state transition (scale). When Reduce Motion is on,
    /// snap between states instead of springing.
    private var dragStateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)
    }

    var body: some View {
        heroLayout
        .overlay(alignment: .trailing) {
            if showsRail {
                GraduationRail(
                    value: value,
                    step: step,
                    spacing: max(pointsPerStep, 7),
                    visible: isDragging || isCoasting
                )
            }
        }
        .overlay(alignment: .top) {
            if wallFlashEdge == .top { wallFlashLine }
        }
        .overlay(alignment: .bottom) {
            if wallFlashEdge == .bottom { wallFlashLine }
        }
        .offset(y: rubberOffset + nudgeOffset)
        .scaleEffect(reduceMotion ? 1.0 : (isDragging ? 1.04 : 1.0))
        .animation(valueAnimation, value: value)
        .animation(dragStateAnimation, value: isDragging)
        .animation(.easeInOut(duration: 0.3), value: showsScrubHint)
        .animation(.easeInOut(duration: 0.4), value: hasScrubbed)
        .contentShape(Rectangle().inset(by: -hitSlop))
        .gesture(scrubGesture)
        .onChange(of: gestureActive) { _, active in
            // A cancelled drag never reaches onEnded; without this
            // sweep the next touch would inherit a stale anchor and
            // teleport the value.
            if !active, isDragging || axisClaim != .undecided {
                axisClaim = .undecided
                if isDragging { finishDrag() }
            }
        }
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
        .onDisappear {
            nudgeTask?.cancel()
            coastTask?.cancel()
            isCoasting = false
        }
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
                rolls: !isDragging && !isCoasting,
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

    /// Invisible worst-case row: the range's upper bound rendered with
    /// the same fonts and spacing as `numberUnitRow`. Its measured
    /// width drives `fitScale`, so the scale is fixed for the whole
    /// scrub regardless of the live value's digit count. A plain Text
    /// matches DigitTicker's per-glyph width because the font is
    /// monospaced.
    private var sizingRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
            Text(format(range.upperBound))
                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: unitFontSize, weight: .semibold, design: .monospaced))
            }
        }
    }

    /// When `fitsWidth` is off, the number keeps its intrinsic width
    /// (galleries, editors). When on, the row is uniformly scaled by
    /// `fitScale` — derived from the hidden `sizingRow`, which lives
    /// in an overlay so it can never influence layout — and its frame
    /// is capped at the scaled width so the intrinsic 104pt row can
    /// never stretch the parent card. `scaleEffect` doesn't change
    /// layout, so measuring stays free of feedback.
    @ViewBuilder
    private var heroLayout: some View {
        if fitsWidth {
            HStack(alignment: .center, spacing: Space.sm) {
                numberUnitRow
                    .fixedSize(horizontal: true, vertical: false)
                    .background(widthReader($naturalWidth))
                    .scaleEffect(fitScale, anchor: .leading)
                    .frame(width: naturalWidth > 0 ? naturalWidth * fitScale : nil, alignment: .leading)
                hintChevrons
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(widthReader($availableWidth))
            .overlay(alignment: .leading) {
                sizingRow
                    .fixedSize()
                    .background(widthReader($templateWidth))
                    .hidden()
            }
        } else {
            HStack(alignment: .center, spacing: Space.sm) {
                numberUnitRow
                hintChevrons
            }
        }
    }

    /// Uniform shrink factor (≤ 1) that fits the worst-case number row
    /// into the offered width, reserving a little room for the
    /// chevrons while the first-use hint is showing. Constant during a
    /// scrub because it depends on the range, not the live value.
    private var fitScale: CGFloat {
        guard fitsWidth, templateWidth > 0, availableWidth > 0 else { return 1 }
        let reserve: CGFloat = (showsScrubHint && !hasScrubbed) ? (Space.sm + 16) : 0
        let target = max(1, availableWidth - reserve)
        guard templateWidth > target else { return 1 }
        return target / templateWidth
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
            .updating($gestureActive) { _, state, _ in state = true }
            .onChanged { drag in
                guard isEnabled else { return }

                switch axisClaim {
                case .horizontal:
                    // A page swipe (or any sideways drag) owns this
                    // touch. Stay silent for its whole lifetime.
                    return
                case .undecided:
                    // Abort any in-flight first-use nudge so its bob
                    // never competes with the user's touch.
                    nudgeTask?.cancel()
                    nudgeOffset = 0
                    // A touch grabs the flywheel: any in-flight coast
                    // stops dead the instant a finger lands.
                    coastTask?.cancel()
                    isCoasting = false
                    let tw = abs(drag.translation.width)
                    let th = abs(drag.translation.height)
                    guard max(tw, th) >= Self.axisClaimDistance else { return }
                    guard th >= tw else {
                        axisClaim = .horizontal
                        return
                    }
                    axisClaim = .vertical
                    // Anchor at the fixed claim distance, not at the
                    // event that happened to cross it — a fast flick's
                    // first decisive event can already be tens of
                    // points in, and anchoring there would silently
                    // swallow that travel. This keeps the dead-band
                    // exactly `axisClaimDistance` at every speed.
                    claimBaselineY = drag.translation.height >= 0
                        ? Self.axisClaimDistance
                        : -Self.axisClaimDistance
                    isDragging = true
                    dragStartValue = value
                    lastStepReported = 0
                    didHitMin = false
                    didHitMax = false
                case .vertical:
                    break
                }

                let translationY = drag.translation.height - claimBaselineY
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
                        fireWallFlash(.bottom)
                        didHitMin = true
                    }
                } else if proposedValue > range.upperBound {
                    rubberOffset = -rubberband(pointsOver)
                    if !didHitMax {
                        Haptics.rigid(pitch: Haptics.ceilingPitch)
                        fireWallFlash(.top)
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
            .onEnded { drag in
                let ownedDrag = axisClaim == .vertical
                axisClaim = .undecided
                guard ownedDrag else { return }
                let momentum = drag.predictedEndTranslation.height - drag.translation.height
                finishDrag()
                startCoast(momentumPoints: momentum)
            }
    }

    private func finishDrag() {
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

    // MARK: - Flywheel coast

    /// A released flick keeps the value rolling. The drag's projected
    /// momentum converts to a run of detents stepped through with
    /// decaying velocity — each detent ticks (sound pitch still
    /// tracking the climb), a wall stops the flywheel with the rigid
    /// end-stop + flash + a rubber bump. Damped well below 1:1 so a
    /// coast reads as "heavy wheel", not "runaway value". Skipped
    /// under Reduce Motion: the value moving beyond the finger is
    /// exactly the surprise that setting exists to prevent.
    private func startCoast(momentumPoints: CGFloat) {
        guard !reduceMotion, isEnabled else { return }
        let projected = Int((-momentumPoints / pointsPerStep * 0.45).rounded())
        guard abs(projected) >= 2 else { return }
        let capped = max(-24, min(24, projected))
        let direction: Double = capped > 0 ? 1 : -1
        let total = abs(capped)
        let anchor = dragStartValue
        // Each detent takes a bit longer than the last; the ratio is
        // sized so the final detent lands ~5× slower than the first.
        let growth = pow(5.0, 1.0 / Double(max(total - 1, 1)))

        coastTask?.cancel()
        coastTask = Task { @MainActor in
            isCoasting = true
            defer { isCoasting = false }
            var interval = 0.028
            for _ in 0..<total {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                let next = value + direction * step
                let clamped = min(max(next, range.lowerBound), range.upperBound)
                guard clamped != value else {
                    Haptics.rigid(pitch: direction > 0 ? Haptics.ceilingPitch : 0)
                    fireWallFlash(direction > 0 ? .top : .bottom)
                    bumpRubber(direction: direction)
                    return
                }
                value = clamped
                let totalDelta = (clamped - anchor) / step
                Haptics.tick(pitch: totalDelta / 20, tone: tickTone)
                interval *= growth
            }
        }
    }

    /// The flywheel slamming a wall mid-coast: a small offset bump on
    /// the wall's side that springs back — the coast's version of the
    /// live drag's rubber-band.
    private func bumpRubber(direction: Double) {
        withAnimation(.easeOut(duration: 0.08)) {
            rubberOffset = direction > 0 ? -12 : 12
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(0.08)) {
            rubberOffset = 0
        }
    }

    // MARK: - Wall flash

    /// Light the end-stop: instant on, lamp-decay off. Fired in the
    /// same frame as the rigid haptic + sound so the wall is one
    /// event across all three senses.
    private func fireWallFlash(_ edge: Edge) {
        guard !reduceMotion else { return }
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            wallFlashEdge = edge
            wallFlashOpacity = 0.95
        }
        withAnimation(.easeOut(duration: 0.45)) {
            wallFlashOpacity = 0
        }
    }

    private var wallFlashLine: some View {
        Capsule()
            .fill(Tint.primary)
            .frame(height: 2)
            .opacity(wallFlashOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
            Haptics.rigid(pitch: direction > 0 ? Haptics.ceilingPitch : 0)
            fireWallFlash(direction > 0 ? .top : .bottom)
        }
    }

    private var formattedValue: String { format(value) }

    /// Shared by the visible value and the worst-case sizing template
    /// so both always render through the same formatting path.
    private func format(_ v: Double) -> String {
        if let formatter { return formatter(v) }
        let isIntegerStep = step.truncatingRemainder(dividingBy: 1) == 0
        return isIntegerStep ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

/// The scrub mechanism made visible: a vertical strip of graduation
/// marks that rides the value 1:1 past a fixed needle, one mark per
/// detent, a taller mark every fifth. Fades in only while the scrub
/// (or its coast) is live and evaporates on release — mechanism on
/// demand, never chrome. Drawn with Canvas so the 60fps slide costs
/// one layer, not a reflow.
private struct GraduationRail: View {
    let value: Double
    let step: Double
    let spacing: CGFloat
    let visible: Bool

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let stepsFromZero = value / max(step, .ulpOfOne)
            let baseIndex = Int(stepsFromZero.rounded(.down))
            let fraction = CGFloat(stepsFromZero - Double(baseIndex))
            let reach = Int(midY / spacing) + 2

            for offset in -reach...reach {
                let index = baseIndex + offset
                // Marks ride WITH the finger: value up → strip up, so
                // higher detents start below the needle and get pulled
                // up to it as the value climbs.
                let y = midY + (CGFloat(offset) - fraction) * spacing
                guard y >= 0, y <= size.height else { continue }
                let isMajor = ((index % 5) + 5) % 5 == 0
                let width: CGFloat = isMajor ? 14 : 8
                let centerDistance = abs(y - midY) / max(midY, 1)
                let edgeFade = pow(max(0, 1 - centerDistance), 1.5)
                let base = isMajor ? 0.55 : 0.30
                context.fill(
                    Path(CGRect(x: size.width - width, y: y - 0.5, width: width, height: 1)),
                    with: .color(Ink.primary.opacity(base * edgeFade))
                )
            }

            context.fill(
                Path(CGRect(x: size.width - 18, y: midY - 0.75, width: 18, height: 1.5)),
                with: .color(Tint.primary.opacity(0.9))
            )
        }
        .frame(width: 22)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.16), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

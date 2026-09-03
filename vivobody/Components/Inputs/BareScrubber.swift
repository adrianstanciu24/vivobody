//
//  BareScrubber.swift
//  vivobody
//
//  Effect host and accessible hero layout for the vertical numeric scrubber.
//  Pure drag and flywheel calculations live in ScrubMotionPolicy.
//

import SwiftUI
import VivoKit

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
    /// Contextual VoiceOver noun, such as "Weight" or "Reps".
    var accessibilityLabel: String? = nil
    /// Shows the app-wide first-use affordance until any number is scrubbed.
    var showsScrubHint: Bool = false
    /// Performs the one-time nudge only for the card's primary number.
    var performsScrubNudge: Bool = false
    /// Fits the range's widest formatted value without live-value resizing.
    var fitsWidth: Bool = false
    /// Opt-in centering; Active Workout's panel-grid default is leading.
    var centersValue: Bool = false
    /// Load scrubbers use `.deep`; counts and duration use `.standard`.
    var tickTone: Haptics.TickTone = .standard
    /// Extra hit-test reach beyond the glyphs; zero on dense editor rows.
    var hitSlop: CGFloat = 0
    /// Shows the transient graduation rail on full-width hero scrubbers.
    var showsRail: Bool = false
    /// Rail space for non-full-width layouts; ignored by full-width heroes.
    var railClearance: CGFloat = 0
    /// Invalidates motion before completion, archive, and discard transitions.
    var cancellationID: Int = 0
    /// Flushes coalesced state after a drag or its coast fully settles.
    var onScrubEnded: () -> Void = {}

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.hasScrubbedNumber) private var hasScrubbed: Bool = SettingsDefaults.hasScrubbedNumber

    @State private var dragState = ScrubDragState()
    @State private var rubberOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var ignoresCurrentGesture = false
    @State private var isCoasting = false
    @State private var coastTask: Task<Void, Never>?
    @State private var coastGeneration = 0
    @State private var wallFlashEdge: Edge?
    @State private var wallFlashOpacity: Double = 0
    @GestureState private var gestureActive = false
    @State private var dragClaimTime: Date = .distantPast
    @State private var nudgeOffset: CGFloat = 0
    @State private var hasNudged = false
    @State private var nudgeTask: Task<Void, Never>?
    @State private var naturalWidth: CGFloat = 0
    @State private var templateWidth: CGFloat = 0
    @State private var templateHeight: CGFloat = 0
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
                    ScrubGraduationRail(
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: showsScrubHint)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: hasScrubbed)
            .contentShape(Rectangle().inset(by: -hitSlop))
            .gesture(scrubGesture)
            .onChange(of: gestureActive) { _, active in
                // A cancelled drag never reaches onEnded; without this
                // sweep the next touch would inherit a stale anchor and
                // teleport the value.
                if !active, isDragging || dragState.axisClaim != .undecided {
                    dragState.axisClaim = .undecided
                    if isDragging {
                        finishDrag()
                        onScrubEnded()
                    }
                }
                if !active {
                    ignoresCurrentGesture = false
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
            .onChange(of: cancellationID) { _, _ in
                // The owner changes this token only when it is already saving,
                // archiving, or discarding the current in-memory state.
                cancelActiveInteraction(notifyEnd: false)
            }
            .onChange(of: scenePhase) { oldPhase, phase in
                guard oldPhase == .active, phase != .active else { return }
                // Stop the producer before AppRoot's active→inactive save.
                // No coast detent can then land after the forced save.
                cancelActiveInteraction(notifyEnd: false)
            }
            .onDisappear {
                nudgeTask?.cancel()
                cancelActiveInteraction()
            }
            // Give assistive technologies a real ranged control rather than a
            // custom element that only looks adjustable. This supplies finite
            // min/max/current values to the accessibility runtime (and avoids
            // the `nan` value some inspectors emitted for the custom action).
            .accessibilityRepresentation {
                Slider(value: accessibilitySliderBinding, in: range, step: step) {
                    Text(accessibilityLabel ?? "Adjustable value")
                }
                .accessibilityValue("\(formattedValue)\(unit.isEmpty ? "" : " \(unit)")")
                .accessibilityHint("Swipe up or down to change")
            }
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
                font: .system(size: fontSize, weight: .bold),
                color: numberColor,
                fractionalDigits: displayFractionDigits(for: value),
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
        if showsScrubHint, !hasScrubbed {
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
            Text(templateFormat(range.upperBound))
                .font(.system(size: fontSize, weight: .bold))
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: unitFontSize, weight: .semibold, design: .monospaced))
            }
        }
    }

    /// When `fitsWidth` is off, the number keeps its intrinsic width
    /// (galleries, editors). When on, the layout element is a clear
    /// base that takes exactly the offered width and the sizing row's
    /// height; the live number row renders in an OVERLAY on that
    /// base. Overlays never negotiate layout, so the intrinsic 104pt
    /// row can never stretch the parent card — a yet-unmeasured
    /// worst-case value used to overflow the card, get its own
    /// stretched width measured back as "available", and freeze the
    /// whole card oversized until the digit count dropped.
    /// `scaleEffect` doesn't change layout, so measuring stays free
    /// of feedback.
    @ViewBuilder
    private var heroLayout: some View {
        if fitsWidth {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: max(fontSize, templateHeight))
                .background(widthReader($availableWidth))
                .overlay(alignment: fittedContentAlignment) {
                    HStack(alignment: .center, spacing: Space.sm) {
                        numberUnitRow
                            .fixedSize(horizontal: true, vertical: false)
                            .background(widthReader($naturalWidth))
                            .scaleEffect(fitScale, anchor: fittedScaleAnchor)
                            .frame(
                                width: naturalWidth > 0 ? naturalWidth * fitScale : nil,
                                alignment: fittedContentAlignment
                            )
                        hintChevrons
                    }
                }
                .overlay(alignment: .leading) {
                    sizingRow
                        .fixedSize()
                        .background(sizeReader($templateWidth, $templateHeight))
                        .hidden()
                }
        } else {
            HStack(alignment: .center, spacing: Space.sm) {
                numberUnitRow
                hintChevrons
            }
            .padding(.trailing, railClearance)
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

    private var fittedContentAlignment: Alignment {
        centersValue ? .center : .leading
    }

    private var fittedScaleAnchor: UnitPoint {
        centersValue ? .center : .leading
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

    /// Same as `widthReader`, but captures both dimensions.
    private func sizeReader(_ width: Binding<CGFloat>, _ height: Binding<CGFloat>) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    width.wrappedValue = proxy.size.width
                    height.wrappedValue = proxy.size.height
                }
                .onChange(of: proxy.size) { _, s in
                    width.wrappedValue = s.width
                    height.wrappedValue = s.height
                }
        }
    }

    // MARK: - First-use hint

    // The adjacent ScrubHintChevrons view owns its repeating animation state.

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
            Haptics.scrubTick(tone: tickTone)
            try? await Task.sleep(for: .milliseconds(170))
            guard !Task.isCancelled, !isDragging else { nudgeOffset = 0; return }
            withAnimation(.easeInOut(duration: 0.34)) { nudgeOffset = 0 }
        }
    }

    // MARK: - Gesture

    private var motionConfiguration: ScrubMotionConfiguration {
        ScrubMotionConfiguration(range: range, step: step, pointsPerStep: pointsPerStep)
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gestureActive) { _, state, _ in state = true }
            .onChanged { drag in
                guard isEnabled, !ignoresCurrentGesture else { return }

                switch dragState.axisClaim {
                case .horizontal:
                    return
                case .undecided:
                    nudgeTask?.cancel()
                    nudgeOffset = 0
                    cancelCoast()
                case .vertical:
                    break
                }

                let update = ScrubMotionPolicy.dragUpdate(
                    horizontalTranslation: drag.translation.width,
                    verticalTranslation: drag.translation.height,
                    currentValue: value,
                    state: dragState,
                    configuration: motionConfiguration
                )
                if update.beganVerticalDrag {
                    dragClaimTime = drag.time
                    isDragging = true
                }
                guard let adjustment = update.adjustment else {
                    dragState = update.state
                    return
                }

                if value != adjustment.value {
                    value = adjustment.value
                }
                rubberOffset = adjustment.rubberOffset
                dragState = update.state
                applyDragFeedback(adjustment.feedback)
            }
            .onEnded { drag in
                if ignoresCurrentGesture {
                    ignoresCurrentGesture = false
                    dragState.axisClaim = .undecided
                    return
                }
                let ownedDrag = dragState.axisClaim.isVertical
                dragState.axisClaim = .undecided
                guard ownedDrag else { return }
                let momentum = drag.predictedEndTranslation.height - drag.translation.height
                let touchDuration = drag.time.timeIntervalSince(dragClaimTime)
                finishDrag()
                if let plan = ScrubMotionPolicy.coastPlan(
                    momentumPoints: momentum,
                    touchDuration: touchDuration,
                    isEnabled: isEnabled,
                    reduceMotion: reduceMotion,
                    configuration: motionConfiguration
                ) {
                    startCoast(plan)
                } else {
                    onScrubEnded()
                }
            }
    }

    private func applyDragFeedback(_ feedback: [ScrubFeedback]) {
        for event in feedback {
            switch event {
            case let .wall(wall):
                Haptics.rigid(playsSound: false)
                fireWallFlash(wall == .maximum ? .top : .bottom)
            case .detent:
                Haptics.scrubTick(tone: tickTone)
            }
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
        if !hasScrubbed, value != dragState.startValue {
            withAnimation(.easeOut(duration: 0.4)) { hasScrubbed = true }
        }
    }

    // MARK: - Flywheel coast

    private func startCoast(_ plan: ScrubCoastPlan) {
        cancelCoast()
        coastGeneration &+= 1
        let generation = coastGeneration
        isCoasting = true
        coastTask = Task { @MainActor in
            defer {
                if coastGeneration == generation {
                    coastTask = nil
                    isCoasting = false
                    onScrubEnded()
                }
            }
            for interval in plan.intervals {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                switch ScrubMotionPolicy.coastStep(
                    from: value,
                    direction: plan.direction,
                    configuration: motionConfiguration
                ) {
                case let .advanced(nextValue):
                    value = nextValue
                    Haptics.scrubTick(tone: tickTone)
                case let .hitWall(wall):
                    Haptics.rigid()
                    fireWallFlash(wall == .maximum ? .top : .bottom)
                    bumpRubber(direction: plan.direction)
                    return
                }
            }
        }
    }

    /// Cancel every source that can still emit a detent. Owners that already
    /// persist as part of the same lifecycle action can suppress the end
    /// callback to avoid a duplicate save.
    private func cancelActiveInteraction(notifyEnd: Bool = true) {
        if gestureActive {
            ignoresCurrentGesture = true
        }
        dragState.axisClaim = .undecided
        if isDragging {
            finishDrag()
            if notifyEnd { onScrubEnded() }
        }
        cancelCoast(notifyEnd: notifyEnd)
    }

    private func cancelCoast(notifyEnd: Bool = true) {
        guard let task = coastTask else { return }
        coastGeneration &+= 1
        coastTask = nil
        isCoasting = false
        task.cancel()
        if notifyEnd { onScrubEnded() }
    }

    private func bumpRubber(direction: ScrubDirection) {
        withAnimation(.easeOut(duration: 0.08)) {
            rubberOffset = direction == .increase ? -12 : 12
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

    private var formattedValue: String {
        format(value)
    }

    private var accessibilitySliderBinding: Binding<Double> {
        Binding(
            get: { value.isFinite ? value : range.lowerBound },
            set: { newValue in
                guard newValue.isFinite else { return }
                let clamped = motionConfiguration.clamped(newValue)
                guard clamped != value else { return }
                value = clamped
                Haptics.scrubTick(tone: tickTone)
                if !hasScrubbed {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
                        hasScrubbed = true
                    }
                }
                onScrubEnded()
            }
        )
    }

    /// Live readout. A whole value drops the step's trailing ".0"
    /// (60, not 60.0); any off-grid value keeps the precision it
    /// needs (62.5) so the number always tells the truth.
    private func format(_ v: Double) -> String {
        if let formatter { return formatter(v) }
        let d = displayFractionDigits(for: v)
        return d == 0 ? "\(Int(v))" : String(format: "%.\(d)f", v)
    }

    /// Fraction digits for a live value: the step's precision, unless
    /// the value is whole — then none.
    private func displayFractionDigits(for v: Double) -> Int {
        let d = WeightUnit.fractionDigits(forStep: step, value: v)
        return d > 0 && abs(v - v.rounded()) < 0.001 ? 0 : d
    }

    /// Worst-case sizing keeps the step's precision even when the
    /// upper bound is whole: a mid-scrub value can always grow a
    /// fraction (275 → 272.5), and the fit scale must already
    /// account for it.
    private func templateFormat(_ v: Double) -> String {
        if let formatter { return formatter(v) }
        let d = WeightUnit.fractionDigits(forStep: step, value: v)
        return d == 0 ? "\(Int(v))" : String(format: "%.\(d)f", v)
    }
}

//
//  BareScrubber.swift
//  vivobody
//
//  Shared vertical numeric scrubber with bare and liquid-card presentations.
//  Pure drag and flywheel calculations live in ScrubMotionPolicy.
//

import SwiftUI
import UIKit
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
    /// Optional operator after the rail on compact, intrinsic-width readouts.
    var compactPrefix: String = ""
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
    /// Shows the graduation rail beside the value.
    var showsRail: Bool = false
    /// Keeps the rail visible as an enduring invitation to scrub.
    var keepsRailVisible: Bool = false
    /// Places the rail on the selected side of the number and unit.
    var railEdge: HorizontalEdge = .trailing
    /// Optional extra clearance beyond the rail's standard reserved lane.
    var railClearance: CGFloat = 0
    /// Invalidates motion before completion, archive, and discard transitions.
    var cancellationID: Int = 0
    var presentation: Presentation = .bare
    var cardLabel: String? = nil
    var cardVerticalPadding: CGFloat = 28
    /// Flushes coalesced state after a drag or its coast fully settles.
    var onScrubEnded: () -> Void = {}

    enum Presentation {
        case bare
        case card
    }

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

    /// Animate settled values only. Live drags and coasts must track detents
    /// without lag; Reduce Motion skips the decorative spring.
    private var valueAnimation: Animation? {
        guard !isDragging, !isCoasting else { return nil }
        return reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.75)
    }

    /// Animate drag scale unless Reduce Motion requires an immediate change.
    private var dragStateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)
    }

    var body: some View {
        movingReadout
            .modifier(ScrubberCardSurface(
                isPresented: presentation == .card,
                label: cardLabel,
                verticalPadding: cardVerticalPadding,
                fraction: fillFraction,
                isDragging: isDragging
            ))
            .animation(valueAnimation, value: value)
            .animation(dragStateAnimation, value: isDragging)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: showsScrubHint)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: hasScrubbed)
            .contentShape(RoundedRectangle(cornerRadius: presentation == .card ? Radius.card : 0).inset(by: -hitSlop))
            .gesture(scrubGesture)
            .onChange(of: gestureActive) { _, active in
                // Cancellation bypasses onEnded; discard its stale drag anchor.
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
                    nudgeTask?.cancel()
                    nudgeOffset = 0
                }
            }
            .onChange(of: cancellationID) { _, _ in
                // The owner already saves or discards during this transition.
                cancelActiveInteraction(notifyEnd: false)
            }
            .onChange(of: scenePhase) { oldPhase, phase in
                guard oldPhase == .active, phase != .active else { return }
                // Stop detents before AppRoot's active→inactive save.
                cancelActiveInteraction(notifyEnd: false)
            }
            .onDisappear {
                nudgeTask?.cancel()
                cancelActiveInteraction()
            }
            // A native ranged control supplies finite min/max/current values.
            .accessibilityRepresentation {
                Slider(value: accessibilitySliderBinding, in: range, step: step) {
                    Text(accessibilityLabel ?? cardLabel ?? "Adjustable value")
                }
                .accessibilityValue("\(formattedValue)\(unit.isEmpty ? "" : " \(unit)")")
                .accessibilityHint("Swipe up or down to change")
            }
            .accessibilityRespondsToUserInteraction(true)
    }

    private var movingReadout: some View {
        heroLayout
            .overlay(alignment: .top) {
                if wallFlashEdge == .top { wallFlashLine }
            }
            .overlay(alignment: .bottom) {
                if wallFlashEdge == .bottom { wallFlashLine }
            }
            .offset(y: rubberOffset + nudgeOffset)
            .scaleEffect(reduceMotion || !isDragging ? 1 : (presentation == .card ? 1.03 : 1.04))
    }

    // MARK: - Hero layout

    private var numberUnitRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
            DigitTicker(
                value: value,
                font: .system(size: fontSize, weight: .bold, design: presentation == .card ? .rounded : .default),
                color: numberColor,
                fractionalDigits: displayFractionDigits(for: value),
                rolls: !isDragging && !isCoasting,
                formatter: formatter
            )

            if !unit.isEmpty {
                Text(unit)
                    .font(presentation == .card ? Typography.metricUnit
                        : .system(size: unitFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(unitColor)
            }
        }
    }

    @ViewBuilder
    private var hintChevrons: some View {
        if showsScrubHint, !hasScrubbed, !keepsRailVisible {
            ScrubHintChevrons()
                .transition(.opacity)
        }
    }

    /// Native Text can shrink itself, but range-based fitting keeps the
    /// active instrument's font size stable across live detents.
    @ViewBuilder
    private var heroLayout: some View {
        if fitsWidth {
            let liveSize = rowSize(for: formattedValue)
            let templateSize = rowSize(for: templateFormat(range.upperBound))
            let hintWidth: CGFloat = (showsScrubHint && !hasScrubbed && !keepsRailVisible) ? (Space.sm + 16) : 0
            let reservedWidth = reservedRailWidth + hintWidth
            let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
            let baselineOffset = font.ascender - font.lineHeight / 2
            GeometryReader { proxy in
                let scale = Self.fitScale(
                    availableWidth: proxy.size.width,
                    templateWidth: templateSize.width,
                    reservedWidth: reservedWidth
                )
                HStack(alignment: .center, spacing: Space.sm) {
                    numberUnitRow
                        .fixedSize(horizontal: true, vertical: false)
                        .scaleEffect(scale, anchor: fittedScaleAnchor)
                        .frame(
                            width: liveSize.width * scale,
                            height: templateSize.height,
                            alignment: fittedContentAlignment
                        )
                    hintChevrons
                }
                .frame(
                    width: max(1, (keepsRailVisible
                            ? min(proxy.size.width, liveSize.width * scale + reservedWidth)
                            : proxy.size.width) - reservedRailWidth),
                    alignment: fittedContentAlignment
                )
                .padding(railEdge == .leading ? .leading : .trailing, reservedRailWidth)
                .overlay(alignment: railEdge == .leading ? .leading : .trailing) {
                    graduationRail(scale: scale)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: fittedContentAlignment
                )
            }
            .frame(height: max(fontSize, templateSize.height))
            .alignmentGuide(.lastTextBaseline) { dimensions in
                let scale = Self.fitScale(
                    availableWidth: dimensions.width,
                    templateWidth: templateSize.width,
                    reservedWidth: reservedWidth
                )
                return dimensions.height / 2 + baselineOffset * scale
            }
        } else {
            HStack(alignment: .center, spacing: Space.sm) {
                if !compactPrefix.isEmpty {
                    Text(compactPrefix)
                        .font(Typography.statValue)
                        .foregroundStyle(unitColor)
                        .accessibilityHidden(true)
                }
                numberUnitRow
                hintChevrons
            }
            .padding(railEdge == .leading ? .leading : .trailing, reservedRailWidth)
            .overlay(alignment: railEdge == .leading ? .leading : .trailing) {
                graduationRail(scale: 1)
            }
        }
    }

    @ViewBuilder
    private func graduationRail(scale: CGFloat) -> some View {
        if showsRail {
            ScrubGraduationRail(
                value: value,
                step: step,
                spacing: max(pointsPerStep, 7),
                visible: keepsRailVisible || isDragging || isCoasting,
                engaged: isDragging || isCoasting
            )
            .frame(height: railHeight * scale)
            .scaleEffect(x: railEdge == .leading ? -1 : 1, y: 1)
        }
    }

    /// Slightly taller than the cap height, so the rail reads as part of the numeral.
    private var railHeight: CGFloat {
        UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold).capHeight * 1.25
    }

    /// Depends on the range, not the live value, so the scale stays
    /// constant during a scrub.
    private nonisolated static func fitScale(
        availableWidth: CGFloat,
        templateWidth: CGFloat,
        reservedWidth: CGFloat
    ) -> CGFloat {
        guard templateWidth > 0, availableWidth > 0 else { return 1 }
        let target = max(1, availableWidth - reservedWidth)
        guard templateWidth > target else { return 1 }
        return target / templateWidth
    }

    private var reservedRailWidth: CGFloat {
        showsRail ? max(railClearance, ScrubGraduationRail.width + Space.sm) : railClearance
    }

    private var fittedContentAlignment: Alignment {
        centersValue ? .center : .leading
    }

    private var fittedScaleAnchor: UnitPoint {
        centersValue ? .center : .leading
    }

    private func rowSize(for number: String) -> CGSize {
        let numberFont = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let numberSize = (number as NSString).size(withAttributes: [.font: numberFont])
        guard !unit.isEmpty else {
            return CGSize(width: ceil(numberSize.width), height: ceil(numberFont.lineHeight))
        }

        let unitFont = UIFont.monospacedSystemFont(ofSize: unitFontSize, weight: .semibold)
        let unitSize = (unit as NSString).size(withAttributes: [.font: unitFont])
        return CGSize(
            width: ceil(numberSize.width + Space.sm + unitSize.width),
            height: ceil(max(numberFont.lineHeight, unitFont.lineHeight))
        )
    }

    // MARK: - First-use hint

    /// A one-time nudge teaches the gesture; real drags cancel it immediately.
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
                // Cards keep their established stop-on-release behavior.
                if presentation == .bare, let plan = ScrubMotionPolicy.coastPlan(
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
        // The first scrub that moves the value retires the first-use hint app-wide.
        if !hasScrubbed, value != dragState.startValue {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { hasScrubbed = true }
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

    /// Fires in the same frame as the rigid haptic and sound, so the wall
    /// reads as one event.
    private func fireWallFlash(_ edge: Edge) {
        guard presentation == .bare, !reduceMotion else { return }
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

    private func format(_ v: Double) -> String {
        if let formatter { return formatter(v) }
        let d = displayFractionDigits(for: v)
        return d == 0 ? "\(Int(v))" : v.formatted(.number.precision(.fractionLength(d)).grouping(.never))
    }

    /// Bare readouts drop a whole value's trailing ".0" (60, not 60.0);
    /// off-grid values keep the step's precision (62.5).
    private func displayFractionDigits(for v: Double) -> Int {
        let d = WeightUnit.fractionDigits(forStep: step, value: v)
        return presentation == .bare && d > 0 && abs(v - v.rounded()) < 0.001 ? 0 : d
    }

    /// Reserve fractional width even when the range's upper bound is whole.
    private func templateFormat(_ v: Double) -> String {
        if let formatter { return formatter(v) }
        let d = WeightUnit.fractionDigits(forStep: step, value: v)
        return d == 0 ? "\(Int(v))" : v.formatted(.number.precision(.fractionLength(d)).grouping(.never))
    }

    private var fillFraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return max(0.06, min(1, (value - range.lowerBound) / span))
    }
}

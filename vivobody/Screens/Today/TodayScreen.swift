//
//  TodayScreen.swift
//  vivobody
//
//  The app's home tab. Quiet, scannable, anchored by the big
//  "Start Workout" call-to-action. Composes previously-built
//  atoms into their first real screen home:
//    • StreakCalendar — the current month with workout dots + PR pulse
//    • PrimaryActionButton — the START WORKOUT call-to-action
//    • DigitTicker — used inside the LastWorkout stats strip
//
//  The screen reads AppState directly (workout dates, PR dates,
//  last completed session) and emits a single intent: start today's
//  workout. The shell handles presentation.
//

import VivoKit
import SwiftUI
import SwiftData

struct TodayScreen: View {
    @Bindable var appState: AppState

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// All archived sessions, most-recent first. Drives the streak
    /// calendar, the "X this month" stat, and the "Last Workout"
    /// card. SwiftUI re-renders this screen automatically when a new
    /// session is inserted into the context (i.e. on workout archive).
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    var completedSessions: [WorkoutSession]

    /// All saved templates. Sorted on-the-fly into a most-recently-
    /// used-first list for the chip strip; the raw @Query order
    /// doesn't matter beyond identity.
    @Query var templates: [WorkoutTemplate]

    /// Frozen on first layout and never updated afterwards. The
    /// scroll container's height shrinks as the large navigation
    /// title collapses on scroll; binding the SCNView's height to
    /// that live value made the model visibly re-scale ("zoom") mid-
    /// scroll. Capturing the height once decouples the model from the
    /// title animation so it holds a constant size.
    @State var heroHeight: CGFloat = 0

    /// Whether the start-workout sheet is presented (raised by the
    /// pinned "+ Start" pill).
    @State var showStartSheet = false

    /// The start action chosen in the sheet, deferred until the sheet
    /// fully dismisses. Running it in the sheet's onDismiss avoids
    /// presenting the focused ActiveWorkoutScreen over a still-
    /// dismissing sheet.
    @State private var pendingStart: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
                ScrollView {
                    // The body leads — your trained figure is the hero
                    // and the readout's subject. The readiness line gives
                    // it a voice; then START is the biggest, first-thing-
                    // you-reach target. The calendar and last workout are
                    // the journal you scroll down to once you've decided.
                    //
                    // The development model is replayed once per data
                    // change (memoised in SessionAnalytics on AppState)
                    // and every consumer (figure, readiness words, the
                    // drill-down boards) derives from this single state.
                    let _ = appState.analytics.update(for: completedSessions)
                    let modelState = appState.analytics.development
                    let upNext = UpNext.compute(templates: templates, sessions: completedSessions)
                    let attention = attentionMuscles()
                    let outlook = appState.analytics.strength
                    VStack(alignment: .leading, spacing: Space.section) {
                        // The figure and its caption read as one unit: the
                        // portrait, then the line decoding its colours sitting
                        // just beneath the feet (over the plain background, not
                        // over the model — the muscle detail made an overlaid
                        // caption unreadable).
                        VStack(spacing: Space.sm) {
                            bodyModelHero(
                                height: bodyHeroHeight(viewport: proxy.size.height),
                                state: modelState
                            )
                            figureCaption
                        }
                            // Depth: the figure settles back into the forge as
                            // you scroll past it. Driven by .scrollTransition
                            // (render-thread) rather than a scroll-offset
                            // @State, so it never re-runs the body model's
                            // channel computation per frame — that was what
                            // made scrolling feel like slow motion.
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .scaleEffect(1 - abs(phase.value) * 0.07, anchor: .top)
                                    .opacity(1 - abs(phase.value) * 0.30)
                            }
                            .settleIn(0)
                        if !attention.isEmpty {
                            needsAttentionSection(attention).settleIn(1)
                            SectionDivider().settleIn(2)
                        }
                        if upNext.isPresentable {
                            upNextView(upNext, outlook: outlook).settleIn(3)
                            SectionDivider().settleIn(4)
                        }
                        consistencySection.settleIn(5)
                        SectionDivider().settleIn(6)
                        lastWorkoutSection.settleIn(7)
                    }
                    .padding(.top, Space.xs)
                    .padding(.bottom, Space.xxl)
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .safeAreaPadding(.bottom, Self.pinnedStartBarClearance)
                // START is pinned in the native iOS 26 safe-area bar,
                // never part of the scroll. The matching safe-area
                // padding above reserves its occupied height so body
                // copy never sits underneath the CTA or tab chrome.
                .safeAreaBar(edge: .bottom, spacing: 0) { pinnedStartBar }
                // The living atmosphere shared with every sibling tab:
                // heat leaking at the chassis seams at a temperature set
                // by streak + recency, so home reads as a powered-on
                // instrument rather than a flat black report. The seam
                // hugs the screen edges, so the faceplate behind the
                // figure and copy stays pure black. `forgeBackground`
                // also mirrors the ember under the nav/tab bars so it
                // never hard-edges.
                .forgeBackground()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
                    // Latch onto the LARGEST viewport height ever seen, not
                    // the first. Native bottom chrome can make the container
                    // report a transient, collapsed height during launch
                    // layout; freezing that first value shrank the hero to a
                    // thumbnail. Tracking the max ignores the transient (and
                    // the on-scroll tab-bar minimize never shrinks the figure,
                    // since the value only grows).
                    if newHeight > heroHeight { heroHeight = newHeight }
                }
        }
        .onAppear {
            Haptics.prepare()
            // A soft "powered-on" tick as the screen settles in — the
            // ambient-confirmation cousin of the workout's haptics.
            Haptics.soft()
        }
        .sheet(isPresented: $showStartSheet, onDismiss: runPendingStart) {
            StartWorkoutSheet(
                lastSession: completedSessions.first,
                templates: sortedTemplates,
                onSelect: queueStart
            )
        }
    }

    // MARK: - Start intent

    /// Record the chosen start path and let the sheet dismiss. The
    /// work runs in `runPendingStart` once the sheet is gone, so the
    /// focused ActiveWorkoutScreen never presents over a dismissing
    /// sheet.
    private func queueStart(_ intent: StartIntent) {
        switch intent {
        case .repeatLast:
            let last = completedSessions.first
            pendingStart = { appState.workout.startTodaysWorkout(basedOn: last) }
        case .fresh:
            pendingStart = { appState.workout.startTodaysWorkout(basedOn: nil) }
        case .template(let template):
            pendingStart = { appState.workout.startWorkoutFromTemplate(template) }
        }
    }

    private func runPendingStart() {
        let action = pendingStart
        pendingStart = nil
        action?()
    }

}

/// Circular recency ring for one neglected-muscle tile. The arc
/// animates from empty to its fill fraction on appear, so the ring
/// "fills" as the section settles in. Honors Reduce Motion by
/// showing the final value immediately.
struct AttentionRing: View {
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Surface.edge, lineWidth: 3)
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: shown ? fraction : 0)
                    .stroke(
                        Tint.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 40, height: 40)
        .onAppear {
            if reduceMotion {
                shown = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                    shown = true
                }
            }
        }
    }
}

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}

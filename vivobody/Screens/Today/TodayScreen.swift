//
//  TodayScreen.swift
//  vivobody
//
//  The app's home tab. Quiet, scannable, anchored by the big
//  "Start Workout" call-to-action. Composes previously-built
//  atoms into their first real screen home:
//    • ConsistencyStrip — the rolling two weeks of workout embers, sized
//      by each day's tonnage, with the PR pulse on record days
//    • PrimaryActionButton — the START WORKOUT call-to-action, which
//      becomes the resume/finish control while a workout is running
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
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Recent archived sessions (a ~45-day window), most-recent
    /// first. Drives the consistency strip, its session count, and
    /// the Up Next trained-today check. Deliberately windowed —
    /// lifetime aggregates (streak, PR sessions, stage warmth) come
    /// from the shared analytics cache, so Today never has to fault
    /// the whole archive. SwiftUI re-renders this screen automatically
    /// when a new session is inserted into the context.
    @Query var recentSessions: [WorkoutSession]

    /// The single most recent archived session, regardless of age —
    /// the "Last Workout" card must survive a long training gap that
    /// falls outside the recent window.
    @Query var latestSessions: [WorkoutSession]

    var latestSession: WorkoutSession? { latestSessions.first }

    /// All saved templates. Sorted on-the-fly into a most-recently-
    /// used-first list for the chip strip; the raw @Query order
    /// doesn't matter beyond identity.
    @Query var templates: [WorkoutTemplate]

    init(appState: AppState) {
        self.appState = appState

        // The window is anchored once at view construction. 45 days
        // comfortably covers the rolling two-week strip and the Up
        // Next lookback for any realistic app-resident stretch.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoff = calendar.date(byAdding: .day, value: -45, to: today) ?? today
        _recentSessions = Query(
            filter: #Predicate<WorkoutSession> {
                $0.completedAt != nil && $0.startedAt >= cutoff
            },
            sort: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        var latest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        latest.fetchLimit = 1
        _latestSessions = Query(latest)
    }

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
    @State var showMuscleMapDetails = false
    @State var showTrainingLoadDetails = false

    /// The start action chosen in the sheet, deferred until the sheet
    /// fully dismisses. Running it in the sheet's onDismiss avoids
    /// presenting the next workout surface over a still-dismissing
    /// sheet.
    @State private var pendingStart: (() -> Void)?

    /// Fresh workouts begin in the exercise catalog rather than on
    /// an empty active-workout canvas. The selected item is likewise
    /// deferred until the picker dismisses, so the active workout
    /// never competes with an outgoing sheet presentation.
    @State private var showFreshExercisePicker = false
    @State private var pendingFreshStart: (() -> Void)?

    var body: some View {
        let shouldReduceMotion = reduceMotion
        ScrollView {
                    // The body leads — your trained figure is the hero
                    // and the readout's subject. The readiness section
                    // below draws how ready it is to train again; START
                    // is the biggest, first-thing-you-reach target. The
                    // calendar and last workout are the journal you
                    // scroll down to once you've decided.
                    //
                    // The development model is replayed once per data
                    // change (memoised in SessionAnalytics on AppState)
                    // and every consumer (figure, readiness card, the
                    // drill-down boards) derives from this single state.
                    let modelState = appState.analytics.development
                    let upNext = UpNext.compute(
                        templates: templates,
                        sessions: recentSessions,
                        load: appState.analytics.load
                    )
                    let outlook = appState.analytics.strength
                    let load = appState.analytics.load
                    let readiness = latestSessions.readiness(load: load)
                    VStack(alignment: .leading, spacing: Space.section) {
                        // The figure and its caption read as one unit: the
                        // portrait, then the line decoding its colours sitting
                        // just beneath the feet (over the plain background, not
                        // over the model — the muscle detail made an overlaid
                        // caption unreadable).
                        VStack(spacing: Space.section) {
                            bodyModelHero(
                                height: bodyHeroHeight(),
                                state: modelState
                            )
                            figureCaption
                        }
                            // Depth: the figure settles back into the stage as
                            // you scroll past it. Driven by .scrollTransition
                            // (render-thread) rather than a scroll-offset
                            // @State, so it never re-runs the body model's
                            // channel computation per frame — that was what
                            // made scrolling feel like slow motion.
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .scaleEffect(
                                        shouldReduceMotion ? 1 : 1 - abs(phase.value) * 0.07,
                                        anchor: .top
                                    )
                                    .opacity(shouldReduceMotion ? 1 : 1 - abs(phase.value) * 0.30)
                            }
                            .settleIn(0)

                        if let readiness {
                            readinessSection(load, line: readiness).settleIn(1)
                            SectionDivider().settleIn(2)
                        }
                        if upNext.isPresentable {
                            upNextView(upNext, outlook: outlook).settleIn(3)
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
                // Keep the content on the app's static, edge-to-edge
                // faceplate. The body-model stage carries the hero's
                // training-driven warmth without continuously animating
                // the entire screen background.
                .screenBackground()
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
        .onAppear {
            Haptics.prepare()
            // A soft "powered-on" tick as the screen settles in — the
            // ambient-confirmation cousin of the workout's haptics.
            Haptics.soft()
        }
        .sheet(isPresented: $showStartSheet, onDismiss: runPendingStart) {
            StartWorkoutSheet(
                lastSession: latestSession,
                templates: sortedTemplates,
                onSelect: queueStart
            )
        }
        .sheet(isPresented: $showFreshExercisePicker, onDismiss: runPendingFreshStart) {
            ExercisePickerSheet { item in
                pendingFreshStart = {
                    appState.workout.startFreshWorkout(with: item)
                }
            }
        }
        .sheet(isPresented: $showMuscleMapDetails) {
            MuscleMapDetailsSheet(report: appState.analytics.muscleMap)
        }
        .sheet(isPresented: $showTrainingLoadDetails) {
            TrainingLoadDetailsSheet(report: appState.analytics.load)
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
            let last = latestSession
            pendingStart = { appState.workout.startTodaysWorkout(basedOn: last) }
        case .fresh:
            if appState.workout.activeSession != nil {
                pendingStart = { appState.workout.expandWorkout() }
            } else {
                pendingStart = { showFreshExercisePicker = true }
            }
        case .template(let template):
            pendingStart = { appState.workout.startWorkoutFromTemplate(template) }
        }
    }

    private func runPendingStart() {
        let action = pendingStart
        pendingStart = nil
        action?()
    }

    private func runPendingFreshStart() {
        let action = pendingFreshStart
        pendingFreshStart = nil
        action?()
    }

    /// At accessibility text sizes the body remains useful context,
    /// but it no longer consumes nearly a full viewport before the
    /// text-based training information begins.
    var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

}

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}

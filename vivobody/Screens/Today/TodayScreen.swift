//
//  TodayScreen.swift
//  vivobody
//
//  The app's home tab and sole owner of Today queries, navigation, and
//  drill-out presentation state. WorkoutStartFlow presents its start
//  sheets. Focused sections render immutable or explicit inputs around
//  one pinned action.
//  A wide, regular-width window splits the same sections into two panes
//  (TodaySplitContent.swift); every other window scrolls them in one column.
//

import SwiftData
import SwiftUI
import VivoKit

struct TodayScreen: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.appDisplayLayout) private var displayLayout

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    @AppStorage(SettingsKey.defaultRestSeconds)
    private var defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds

    var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

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

    var latestSession: WorkoutSession? {
        latestSessions.first
    }

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

    /// The figure's latched container reading. Sizing the SCNView from the
    /// live scroll container made the model visibly re-scale ("zoom") on
    /// every layout pass; the latch changes only for a new width or a
    /// larger reading.
    @State var heroSizing = TodayHeroSizing()

    /// Opens the shared start flow: the fresh exercise picker or the chooser.
    @State var isStartRequested = false
    @State var showMuscleMapDetails = false

    var body: some View {
        let upNext = UpNext.compute(
            templates: templates,
            sessions: recentSessions,
            load: appState.analytics.load
        )
        Group {
            if displayLayout.showsDashboardColumns, #available(iOS 27.1, *) {
                splitContent(upNext: upNext)
            } else {
                singleColumnContent(upNext: upNext)
            }
        }
        // Keep the content on the app's static, edge-to-edge
        // faceplate. The body-model stage carries the hero's
        // training-driven warmth without continuously animating
        // the entire screen background.
        .screenBackground()
        .onAppear { Haptics.prepare() }
        .workoutStartFlow(
            isRequested: $isStartRequested,
            workout: appState.workout,
            lastSession: latestSession,
            templates: sortedTemplates,
            scheduledTemplate: scheduledTemplate(in: upNext)
        )
        .sheet(isPresented: $showMuscleMapDetails) {
            MuscleMapDetailsSheet(report: appState.analytics.muscleMap)
        }
    }

    /// At accessibility text sizes the body remains useful context,
    /// but it no longer consumes nearly a full viewport before the
    /// text-based training information begins.
    var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    // MARK: - Sections

    private func singleColumnContent(upNext: UpNext) -> some View {
        let shouldReduceMotion = reduceMotion
        return ScrollView {
            // The body leads — your trained figure is the hero
            // and the readout's subject. Up Next then names the
            // scheduled plan with its last logged reference;
            // the pinned primary action remains the biggest,
            // first-thing-you-reach target. Consistency and Last
            // workout always follow, as placeholders before the
            // first archived workout.
            VStack(alignment: .leading, spacing: Space.section) {
                bodySection
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

                // An active workout owns the next step, so Up next
                // steps aside entirely rather than showing a placeholder.
                if barSession == nil {
                    upNextSection(upNext)
                }
                SectionDivider()
                consistencySection
                SectionDivider()
                lastWorkoutSection
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        // START is pinned in the native safe-area bar, never part of
        // the scroll. The bar insets the scroll content by its own
        // height at every text size, and the soft edge effect fades
        // content beneath it.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            pinnedStartBar
        }
        // The figure scrolls away as the title collapses here, so the
        // reading leaves out the top inset.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            heroSizing.accept(TodayHeroSizing.Container(size: size))
        }
    }

    /// The figure and its caption read as one unit: the portrait, then the
    /// line decoding its colours just beneath the feet (over the plain
    /// background, not over the model — the muscle detail made an overlaid
    /// caption unreadable).
    ///
    /// The development model is replayed once per data change (memoised in
    /// SessionAnalytics on AppState) and every consumer (figure, readiness
    /// card, the drill-down boards) derives from this single state.
    var bodySection: some View {
        TodayBodySection(
            height: heroSizing.heroHeight(accessibility: usesAccessibilityLayout),
            state: appState.analytics.development,
            warmth: appState.analytics.forgeWarmth,
            colorScheme: colorScheme,
            usesAccessibilityLayout: usesAccessibilityLayout
        ) {
            showMuscleMapDetails = true
        }
    }

    @ViewBuilder
    func upNextSection(_ upNext: UpNext) -> some View {
        if let upNextSelection = makeUpNextSelection(
            upNext,
            outlook: appState.analytics.strength,
            defaultRestSeconds: defaultRestSeconds
        ) {
            TodayUpNextSection(
                presentation: upNextSelection.presentation,
                usesAccessibilityLayout: usesAccessibilityLayout
            ) {
                TemplateDetailScreen(
                    template: upNextSelection.template,
                    appState: appState
                )
            }
        } else {
            TodayUpNextPlaceholder()
        }
    }

    var consistencySection: some View {
        TodayConsistencySection(
            workoutDates: workoutDates,
            prDates: prDates,
            streakText: streakText(appState.analytics.overview.streak)
        ) {
            ConsistencyScreen()
        }
    }

    var lastWorkoutSection: some View {
        TodayLastWorkoutSection(
            summary: latestSession.map { lastWorkoutSummary(for: $0) },
            unit: unit
        )
    }
}

#Preview("Today") {
    NavigationStack {
        TodayScreen(appState: AppState())
            .navigationTitle("Today")
    }
    .preferredColorScheme(.dark)
}

//
//  AppRoot.swift
//  vivobody
//
//  Top-level container. Owns the AppState and wires together three
//  native iOS 26 chrome elements:
//
//    1. TabView with Tab(…) — Liquid Glass floating tab bar, large
//       per-tab nav titles, minimize-on-scroll behavior.
//    2. .tabViewBottomAccessory — the MiniBar pill that sits above
//       the tab bar whenever a workout is running. Tapping it expands
//       the workout back to the full screen. Inspired by Music's
//       MiniPlayer.
//    3. .sheet(isPresented:) — the focused ActiveWorkoutScreen
//       when the workout is expanded. Presented as a .large sheet
//       with a grabber so swipe-down minimizes it back to the MiniBar
//       (Music-style). Hides the tab bar while expanded.
//
//  Session lifetime vs. presentation lifetime are intentionally
//  decoupled here: `appState.activeSession != nil` controls whether the
//  MiniBar exists; `appState.isWorkoutExpanded` controls whether the
//  full screen is presented. A workout can be minimized and resumed
//  any number of times before it's archived.
//

import SwiftUI
import SwiftData
import Intents
import CoreSpotlight

struct AppRoot: View {
    @State private var appState = AppState()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// The user's light/dark/system choice. Drives the whole window's
    /// color scheme (system resolving to nil so the OS decides).
    /// Applied at the top of the view tree so the navigation bar's
    /// large titles and the status bar recolor with it.
    @AppStorage(SettingsKey.appearance)
    private var appearanceRaw: String = SettingsDefaults.appearance

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    /// First-launch gate. Once true the welcome screen never shows
    /// again. The fullScreenCover binding is derived from its inverse
    /// so tapping Start (which sets this true) dismisses the cover.
    @AppStorage(SettingsKey.onboardingCompleted)
    private var onboardingCompleted: Bool = SettingsDefaults.onboardingCompleted

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !onboardingCompleted },
            set: { presented in onboardingCompleted = !presented }
        )
    }

    var body: some View {
        tabView
            .preferredColorScheme(appearance.colorScheme)
            .tint(Tint.primary)
            .miniBarAccessory(
                session: appState.activeSession,
                onExpand: { appState.expandWorkout() }
            )
            .saveErrorAlert($appState.lastSaveError)
            .onAppear {
                // Hand the SwiftData write context to AppState on
                // first appear. Subsequent appears are no-ops because
                // the reference doesn't change.
                if appState.modelContext == nil {
                    appState.modelContext = modelContext
                }
#if DEBUG
                UITestSupport.resetIfRequested(in: modelContext)
#endif
                // Seed the exercise catalog on a brand-new install.
                // Idempotent — bails if anything's already there, so
                // re-runs after migrations are cheap.
                ExerciseCatalogItem.seedIfEmpty(in: modelContext)
#if DEBUG
                UITestSupport.seedIfRequested(in: modelContext)
#endif
                ExerciseCatalogItem.backfillCopiedExerciseIdentity(in: modelContext)
                // Mirror the SwiftData store into CoreSpotlight so the
                // user's templates and catalog lifts appear in Spotlight
                // search. Wipes both domains first to drop any stale
                // entries, then re-indexes the current set. Off the main
                // actor inside SpotlightIndexer, so this never blocks.
                SpotlightIndexer.reindexAll(
                    templates: (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? [],
                    items: (try? modelContext.fetch(FetchDescriptor<ExerciseCatalogItem>())) ?? []
                )
                appState.restoreActiveWorkoutIfNeeded()
                consumeWidgetStartRequest()
                consumeTemplateStartRequest()
                consumeCompleteSetRequest()
                WidgetSnapshotWriter.writeAll(in: modelContext)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    consumeWidgetStartRequest()
                    consumeTemplateStartRequest()
                    consumeCompleteSetRequest()
                    WidgetSnapshotWriter.writeAll(in: modelContext)
                    // Back in the foreground the BreathingTimer owns
                    // the rest countdown again — the lock-screen chime
                    // must not double-fire behind it.
                    RestNotificationController.cancelPending()
                } else if appState.activeSession != nil {
                    try? modelContext.save()
                    WidgetSnapshotWriter.writeActiveWorkout(in: modelContext)
                    // Leaving the foreground mid-rest: hand the "rest
                    // over" moment to a local notification so a locked
                    // phone still taps the user at zero.
                    RestNotificationController.scheduleIfResting(for: appState.activeSession)
                }
            }
            .onOpenURL(perform: appState.handleDeepLink)
            // Publish a "continue workout" NSUserActivity while a
            // session is live. isActive flips false when the workout
            // ends (activeSession -> nil), at which point SwiftUI
            // invalidates the activity automatically, so no manual
            // cleanup is needed. The activity drives Handoff, system
            // restore, and Siri Suggestions. Watch handoff is
            // deferred to the watchOS track.
            .userActivity(
                ContinueWorkoutActivity.activityType,
                isActive: appState.activeSession != nil
            ) { activity in
                guard let session = appState.activeSession else { return }
                activity.title = ContinueWorkoutActivity.title(for: session)
                activity.suggestedInvocationPhrase = "Continue my workout"
                activity.isEligibleForHandoff = true
                activity.isEligibleForSearch = false
                activity.isEligibleForPrediction = true
                activity.isEligibleForPublicIndexing = false
                activity.requiredUserInfoKeys = Set([ContinueWorkoutActivity.sessionIDKey])
                activity.userInfo = ContinueWorkoutActivity.userInfo(for: session)
                activity.persistentIdentifier = session.id.uuidString
                activity.targetContentIdentifier = session.id.uuidString
            }
            .onContinueUserActivity(ContinueWorkoutActivity.activityType) { activity in
                guard let id = ContinueWorkoutActivity.sessionID(from: activity) else { return }
                appState.continueWorkout(with: id)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                // A Spotlight search-result tap. The uniqueIdentifier
                // we indexed is "template:<uuid>" or "exercise:<uuid>";
                // split it, fetch the @Model, and route. Template ->
                // start its workout (one tap from Spotlight to lifting).
                // Exercise -> present its detail as a modal sheet (the
                // Library tab has no programmatic push path, so a deep-
                // linked detail is modal). A stale identifier (item
                // deleted since indexing) lands the user on Library.
                guard let uniqueID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                else { return }
                let parts = uniqueID.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2, let uuid = UUID(uuidString: parts[1]) else { return }
                // The continue handler can fire before onAppear wires
                // AppState.modelContext; mirror that wiring so the
                // appState methods that rely on it work on a cold
                // Spotlight launch.
                if appState.modelContext == nil {
                    appState.modelContext = modelContext
                }
                switch parts[0] {
                case "template":
                    var descriptor = FetchDescriptor<WorkoutTemplate>(
                        predicate: #Predicate { $0.id == uuid }
                    )
                    descriptor.fetchLimit = 1
                    if let template = try? modelContext.fetch(descriptor).first {
                        appState.startWorkoutFromTemplate(template)
                        appState.selectedTab = .today
                    } else {
                        appState.selectedTab = .library
                    }
                case "exercise":
                    var descriptor = FetchDescriptor<ExerciseCatalogItem>(
                        predicate: #Predicate { $0.id == uuid }
                    )
                    descriptor.fetchLimit = 1
                    if let item = try? modelContext.fetch(descriptor).first {
                        // Minimize any active workout sheet first so
                        // the two sheets are never presented at once.
                        appState.isWorkoutExpanded = false
                        appState.selectedTab = .library
                        appState.presentSpotlightExercise(item)
                    } else {
                        appState.selectedTab = .library
                    }
                default:
                    break
                }
            }
            .sheet(isPresented: $appState.isWorkoutExpanded) {
                if let session = appState.activeSession {
                    ActiveWorkoutScreen(
                        session: session,
                        onDismiss: { appState.dismissActiveWorkout() },
                        onDiscard: { appState.discardActiveWorkout() }
                    )
                    // Music-style presentation: fills the screen, has
                    // a grabber for swipe-down-to-minimize, and leaves
                    // the presentation chrome to iOS 26's native glass —
                    // including the system's concentric sheet corner
                    // radius, so it stays in lockstep with the device's
                    // own curvature instead of a hardcoded value.
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            // Spotlight-driven exercise detail. Presented modally (not
            // pushed) because the Library tab's NavigationStack has no
            // programmatic push path. Wrapped in a NavigationStack so
            // the detail's .navigationTitle / .toolbar render; swipe-
            // down dismisses and clears pendingSpotlightExercise.
            .sheet(item: $appState.pendingSpotlightExercise) { item in
                NavigationStack {
                    ExerciseDetailScreen(item: item, onPickAndDismiss: nil)
                }
                .presentationDragIndicator(.visible)
            }
            // First-launch welcome. Full-screen (no swipe-to-dismiss)
            // so the only way out is tapping Start, which flips the
            // onboarding flag and dismisses the cover.
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingScreen(onStart: { onboardingCompleted = true })
            }
    }

    private var tabView: some View {
        TabView(selection: $appState.selectedTab) {
            Tab(AppTab.today.label,
                systemImage: AppTab.today.icon,
                value: AppTab.today) {
                NavigationStack {
                    TodayScreen(appState: appState)
                        .navigationTitle("Today")
                }
            }

            Tab(AppTab.history.label,
                systemImage: AppTab.history.icon,
                value: AppTab.history) {
                NavigationStack {
                    HistoryScreen(appState: appState)
                        .navigationTitle("History")
                }
            }

            Tab(AppTab.library.label,
                systemImage: AppTab.library.icon,
                value: AppTab.library) {
                NavigationStack {
                    LibraryScreen(appState: appState)
                        .navigationTitle("Library")
                }
            }

            Tab(AppTab.insights.label,
                systemImage: AppTab.insights.icon,
                value: AppTab.insights) {
                NavigationStack {
                    InsightsScreen(appState: appState)
                        .navigationTitle("Insights")
                }
            }

            Tab(AppTab.me.label,
                systemImage: AppTab.me.icon,
                value: AppTab.me) {
                NavigationStack {
                    MeScreen(appState: appState)
                        .navigationTitle("Me")
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private func consumeWidgetStartRequest() {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            defaults.object(forKey: WidgetShared.startWorkoutRequestKey) != nil,
            appState.activeSession == nil
        else { return }
        defaults.removeObject(forKey: WidgetShared.startWorkoutRequestKey)

        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        ))) ?? []

        switch UpNext.compute(templates: templates, sessions: sessions).kind {
        case let .scheduled(template, _, _):
            appState.startWorkoutFromTemplate(template)
        default:
            appState.startTodaysWorkout(basedOn: sessions.first)
        }
    }

    /// Consume a Siri-shortcut / App Intent request to start a
    /// specific template by UUID. The StartTemplateWorkoutIntent
    /// (declared in AppShortcuts.swift) runs in the system process
    /// and can't open the app's SwiftData store, so it records the
    /// template id here; we fetch the @Model on launch and hand it to
    /// AppState.startWorkoutFromTemplate. Mirrors
    /// consumeWidgetStartRequest, but targeted at a specific template
    /// instead of "today's scheduled" one. No-ops if a workout is
    /// already active or the template no longer exists.
    private func consumeTemplateStartRequest() {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            let idString = defaults.string(forKey: WidgetShared.startTemplateWorkoutRequestKey),
            let uuid = UUID(uuidString: idString),
            appState.activeSession == nil
        else { return }
        defaults.removeObject(forKey: WidgetShared.startTemplateWorkoutRequestKey)

        var descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        guard let template = try? modelContext.fetch(descriptor).first else { return }
        appState.startWorkoutFromTemplate(template)
    }

    private func consumeCompleteSetRequest() {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            defaults.object(forKey: WidgetShared.completeSetRequestKey) != nil,
            let session = appState.activeSession
        else { return }
        defaults.removeObject(forKey: WidgetShared.completeSetRequestKey)

        let exercises = session.orderedExercises
        guard exercises.indices.contains(session.activeExerciseIndex) else { return }
        let exercise = exercises[session.activeExerciseIndex]
        session.completeActiveSet(for: exercise)
        do {
            try modelContext.save()
            WorkoutLiveActivityController.update(for: session)
            WidgetSnapshotWriter.writeActiveWorkout(in: modelContext)
            appState.selectedTab = .today
            appState.isWorkoutExpanded = true
        } catch {
            appState.lastSaveError = SaveErrorBox(error)
        }
    }
}

// MARK: - Conditional MiniBar accessory

/// Applies `.tabViewBottomAccessory` only when a session is active.
/// iOS 26's TabView reserves the accessory slot whenever the modifier
/// is attached — even with empty content — so the only reliable way
/// to hide the pill when there's no workout is to not apply the
/// modifier at all.
private extension View {
    @ViewBuilder
    func miniBarAccessory(
        session: WorkoutSession?,
        onExpand: @escaping () -> Void
    ) -> some View {
        if let session {
            self.tabViewBottomAccessory {
                ActiveWorkoutMiniBar(session: session, onExpand: onExpand)
            }
        } else {
            self
        }
    }
}

#Preview {
    AppRoot()
        .preferredColorScheme(.dark)
}
